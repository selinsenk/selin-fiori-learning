/******************************************************************************
 * srv/tax-service.js  —  THE BUSINESS LOGIC
 *
 * WHAT THIS FILE IS
 * -----------------
 * CDS files are declarative: they describe shapes, not behaviour. When you need
 * real logic ("compute this", "check that", "refuse this") you write a handler
 * file next to the .cds file, with the same base name. CAP finds it by that
 * naming convention alone - there is no registration step.
 *
 *     srv/tax-service.cds  ->  srv/tax-service.js     <- automatic pairing
 *
 * WHAT IT DOES
 * ------------
 * Fills the `virtual calculatedAmount` field of GLAccounts:
 *
 *     calculatedAmount = balanceAmount * (sum of the tax rates) / 100
 *
 * ABAP EQUIVALENT
 * ---------------
 * Two ABAP artifacts do this job, and both are in /abap-reference:
 *
 *   1. ../abap-reference/07-classes/ZCL_TAX_CALCULATOR.clas.abap
 *      the pure calculation, unit-testable, knows nothing about UIs
 *
 *   2. ../abap-reference/07-classes/ZCL_GL_ACCOUNT_CALC.clas.abap
 *      the "exit class" that S/4HANA calls to fill virtual CDS elements
 *      (it implements interface IF_SADL_EXIT_CALC_ELEMENT_READ)
 *
 * The structure below - a hook that receives rows, enriches them, and returns -
 * is deliberately identical to the ABAP one, so you can read them side by side.
 ******************************************************************************/

const cds = require('@sap/cds')


module.exports = class TaxBalanceService extends cds.ApplicationService {

  async init () {

    // `this.entities` gives the entity definitions of THIS service, so we can
    // refer to them as objects instead of magic strings.
    const { GLAccounts, CompanyLayers, TaxRates } = this.entities

    /*========================================================================*
     * HOOK 1 - make sure we always receive the fields we need to calculate
     *
     * OData clients send $select to ask for specific fields only. Fiori Elements
     * is aggressive about this: if a column is not visible, it is not selected.
     * But to compute calculatedAmount we NEED balanceAmount, companyCode and
     * layerID even if the UI never displays them.
     *
     * So we intercept the query before it hits the database and add them.
     * `before` handlers run BEFORE the operation and may modify the request.
     *
     * ABAP equivalent: the GET_CALCULATED_ELEMENTS method of the exit class,
     * which returns the list of fields the framework must additionally read.
     *========================================================================*/
    this.before('READ', GLAccounts, req => {
      const select = req.query?.SELECT
      // No explicit column list means "give me everything" - nothing to do.
      if (!select?.columns) return

      const isSelected = name =>
        select.columns.some(c => c === '*' || c === name || c.ref?.[0] === name)

      for (const required of ['companyCode', 'layerID', 'balanceAmount', 'currency']) {
        if (!isSelected(required)) select.columns.push({ ref: [required] })
      }
    })

    /*========================================================================*
     * HOOK 2 - the actual calculation
     *
     * `after` handlers run AFTER the database returned rows, and receive those
     * rows so they can enrich them. This is where virtual fields get filled.
     *
     * Two ways the UI can ask for GL accounts, so we cover both:
     *   a) direct navigation  .../CompanyLayers(...)/glAccounts   -> target = GLAccounts
     *   b) expand             .../CompanyLayers(...)?$expand=glAccounts -> target = CompanyLayers
     *========================================================================*/
    this.after('READ', GLAccounts, async (rows, req) => {
      // Tip for your own debugging: run the server with DEBUG_DRAFT=1 to see
      // exactly what CAP hands your handler. Printing req.subject.ref is the
      // single most useful thing you can do when a CAP handler misbehaves.
      if (process.env.DEBUG_DRAFT) {
        console.log('>>> subject.ref =', JSON.stringify(req.subject?.ref))
      }
      await enrich(toArray(rows), isDraftRequest(req))
    })

    this.after('READ', CompanyLayers, async (rows, req) => {
      // Collect any GL accounts that came along inside an $expand.
      const nested = toArray(rows).flatMap(r => toArray(r?.glAccounts))
      if (nested.length) await enrich(nested, isDraftRequest(req))
    })


    /*========================================================================*
     * The calculation itself
     *========================================================================*/
    async function enrich (accounts, useDraftRates) {
      if (!accounts.length) return

      // We may have received 30 GL accounts that all belong to the same
      // company/layer. Reading the tax rates 30 times would be 30 database
      // round-trips for the same answer, so we cache per company/layer pair.
      // (In ABAP you would do the same with a sorted internal table + READ TABLE
      //  ... BINARY SEARCH. Avoiding "SELECT inside LOOP" is drilled into every
      //  ABAP developer, because it is the classic performance killer.)
      const rateCache = new Map()

      for (const account of accounts) {
        if (!account || account.companyCode == null || account.layerID == null) continue

        const cacheKey = `${account.companyCode}/${account.layerID}`

        if (!rateCache.has(cacheKey)) {
          rateCache.set(
            cacheKey,
            await readEffectiveRate(account.companyCode, account.layerID, useDraftRates)
          )
        }

        const effectiveRatePercent = rateCache.get(cacheKey)
        const balance = Number(account.balanceAmount ?? 0)

        // THE BUSINESS RULE, in one line.
        //
        // A note on the rule itself, flagged for you as the project brief asked:
        // we SUM the rates (19% VAT + 5.5% surcharge = 24.5%) and apply the sum
        // to the balance. That matches your brief, but be aware it is not how a
        // real German Solidaritätszuschlag works - in reality a surcharge is
        // charged on the TAX, not on the base amount, so it would be
        // 19% + (19% * 5.5%) = 20.045%. We keep the simple sum on purpose; the
        // point here is to learn where logic lives, not tax law.
        //
        // The result is the TAX AMOUNT (balance x rate), not the gross amount.
        // If you wanted the gross you would write balance * (1 + rate/100).
        const raw = balance * effectiveRatePercent / 100

        // Round to 2 decimals. Never let un-rounded floats reach a finance UI.
        account.calculatedAmount = Math.round((raw + Number.EPSILON) * 100) / 100
      }
    }


    /*========================================================================*
     * Read the tax rates for one company/layer and add them up.
     *========================================================================*/
    async function readEffectiveRate (companyCode, layerID, useDraftRates) {

      // ---- DRAFT vs ACTIVE ---------------------------------------------------
      // Remember: a draft-enabled entity physically lives in TWO tables. The
      // active table holds saved data; a shadow "drafts" table holds each user's
      // unsaved edits. CAP exposes the shadow one as `Entity.drafts`.
      //
      // If the user is editing (Tab 1 is in edit mode) we must calculate from
      // what they are typing right now, not from what was last saved -
      // otherwise Tab 2 would look stale while they work.
      const source = useDraftRates ? TaxRates.drafts : TaxRates

      const rates = await SELECT
        .from(source)
        .columns('rateValue')
        .where({ parent_companyCode: companyCode, parent_layerID: layerID })

      // Sum them. `?? 0` guards against an empty row the user just added but
      // has not typed a value into yet.
      return rates.reduce((total, row) => total + Number(row.rateValue ?? 0), 0)
    }

    // Always call super.init() - it registers CAP's own generic handlers
    // (the ones that actually talk to the database, handle draft actions, etc).
    return super.init()
  }
}


/*============================================================================*
 * Small helpers
 *============================================================================*/

// A READ can return one row (object) or many (array). Normalise to an array.
function toArray (x) {
  if (x == null) return []
  return Array.isArray(x) ? x : [x]
}

/**
 * Is this request reading DRAFT data rather than saved data?
 *
 * Every OData URL in a draft-enabled service carries IsActiveEntity, e.g.
 *     /CompanyLayers(companyCode='1000',layerID='01',IsActiveEntity=false)/glAccounts
 * `false` means "the user's private draft copy".
 *
 * BUT - and this is worth knowing, because it is easy to get wrong - by the
 * time a handler runs, CAP has ALREADY interpreted IsActiveEntity for you. It
 * rewrites the query to point at the shadow entity and then REMOVES the
 * IsActiveEntity condition. Dumping req.subject.ref for a draft read shows:
 *
 *   [ { id: 'TaxBalanceService.CompanyLayers.drafts',
 *       where: [ {ref:['companyCode']}, '=', {val:'1000'}, 'and', ... ] },
 *     'glAccounts' ]
 *                        ^^^^^^^ note: ".drafts", and no IsActiveEntity at all
 *
 * So the reliable signal is the entity NAME ending in `.drafts`, not the
 * IsActiveEntity flag. (We still check the flag as a fallback, because a
 * request that reaches a handler before CAP's rewrite - or a hand-written
 * query - may still carry it.)
 */
function isDraftRequest (req) {
  const ref = req.subject?.ref ?? req.query?.SELECT?.from?.ref
  if (!Array.isArray(ref)) return false

  for (const segment of ref) {
    // Primary signal: CAP redirected us to the shadow ("drafts") entity.
    if (typeof segment?.id === 'string' && segment.id.endsWith('.drafts')) return true
    if (typeof segment === 'string' && segment.endsWith('.drafts')) return true

    // Fallback signal: a raw IsActiveEntity=false condition.
    // A parsed condition looks like: [ {ref:['IsActiveEntity']}, '=', {val:false} ]
    const where = segment?.where
    if (!Array.isArray(where)) continue
    for (let i = 0; i < where.length; i++) {
      if (where[i]?.ref?.[0] === 'IsActiveEntity') {
        const value = where[i + 2]?.val
        if (value === false || value === 'false') return true
      }
    }
  }
  return false
}
