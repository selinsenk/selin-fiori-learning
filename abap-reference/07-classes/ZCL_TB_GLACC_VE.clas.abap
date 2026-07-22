"!*****************************************************************************
"! ZCL_TB_GLACC_VE — the virtual element exit class
"!
"! *** THIS IS THE DIRECT COUNTERPART OF srv/tax-service.js. ***
"!
"! It is the class named in ZC_TB_GLAccount.ddls:
"!     @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_TB_GLACC_VE'
"!
"! The framework calls it in two phases, and both phases have an exact twin in
"! our CAP handler file:
"!
"!   ABAP: GET_CALCULATION_INFO   <->  CAP: this.before('READ', GLAccounts, ...)
"!         "which stored fields do I need in order to compute the virtual one?"
"!         In CAP we pushed companyCode / layerID / balanceAmount into
"!         req.query.SELECT.columns for exactly the same reason: the client's
"!         $select may not have asked for them.
"!
"!   ABAP: CALCULATE              <->  CAP: this.after('READ', GLAccounts, ...)
"!         "here are the rows; fill in the virtual field."
"!
"! Both frameworks work the same way because both are solving the same problem:
"! a field that the database cannot produce.
"!*****************************************************************************
CLASS zcl_tb_glacc_ve DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    " Implementing this SAP-delivered interface is what makes the class usable
    " as a virtual element exit. SADL is the layer inside S/4HANA that turns
    " CDS views into OData responses.
    INTERFACES if_sadl_exit_calc_element_read.

  PRIVATE SECTION.

    TYPES: BEGIN OF ty_key,
             company_code TYPE bukrs,
             layer_id     TYPE ztb_layer_id,
           END OF ty_key.

    "! One cached result: for this company/layer, the summed rate.
    TYPES: BEGIN OF ty_cache,
             company_code   TYPE bukrs,
             layer_id       TYPE ztb_layer_id,
             effective_rate TYPE ztb_rate_value,
           END OF ty_cache.

    "! Reads the tax rates for one company/layer and returns their sum.
    "! Mirrors readEffectiveRate() in srv/tax-service.js.
    METHODS get_effective_rate
      IMPORTING is_key                   TYPE ty_key
      RETURNING VALUE(rv_effective_rate) TYPE ztb_rate_value.

ENDCLASS.


CLASS zcl_tb_glacc_ve IMPLEMENTATION.

  "***************************************************************************
  " PHASE 1 - declare the stored fields the calculation depends on
  "***************************************************************************
  METHOD if_sadl_exit_calc_element_read~get_calculation_info.

    " CT_REQUESTED_ORIG_ELEMENTS is a CHANGING parameter: it arrives holding the
    " fields the client asked for, and we ADD the ones we secretly need.
    "
    " Without this, a user who hides the Balance Amount column would get an
    " empty Calculated Amount, because balance_amount would never be read from
    " the database. Exactly the bug the `before READ` hook prevents in CAP.

    " Only do the work if the virtual element was actually requested.
    IF NOT line_exists( it_requested_calc_elements[ table_line = 'CALCULATEDAMOUNT' ] ).
      RETURN.
    ENDIF.

    " APPEND ... TO is the classic way to add a row to an internal table.
    " The IF line_exists( ) guard avoids duplicates, which SADL dislikes.
    IF NOT line_exists( ct_requested_orig_elements[ table_line = 'COMPANYCODE' ] ).
      APPEND 'COMPANYCODE'   TO ct_requested_orig_elements.
    ENDIF.
    IF NOT line_exists( ct_requested_orig_elements[ table_line = 'LAYERID' ] ).
      APPEND 'LAYERID'       TO ct_requested_orig_elements.
    ENDIF.
    IF NOT line_exists( ct_requested_orig_elements[ table_line = 'BALANCEAMOUNT' ] ).
      APPEND 'BALANCEAMOUNT' TO ct_requested_orig_elements.
    ENDIF.
    IF NOT line_exists( ct_requested_orig_elements[ table_line = 'CURRENCY' ] ).
      APPEND 'CURRENCY'      TO ct_requested_orig_elements.
    ENDIF.

  ENDMETHOD.


  "***************************************************************************
  " PHASE 2 - fill the virtual element, row by row
  "***************************************************************************
  METHOD if_sadl_exit_calc_element_read~calculate.

    " ------------------------------------------------------------------------
    " IT_ORIGINAL_DATA and CT_CALCULATED_DATA are generically typed
    " (STANDARD TABLE), because SADL does not know your view's structure at
    " compile time. So we must use FIELD-SYMBOLS and a runtime cast.
    "
    " FIELD-SYMBOLS are ABAP's pointers. `<fs>` is the naming convention.
    " ASSIGNING avoids copying each row - important when a table has 10,000 rows.
    " ------------------------------------------------------------------------
    DATA lt_rate_cache TYPE SORTED TABLE OF ty_cache WITH UNIQUE KEY company_code layer_id.

    LOOP AT ct_calculated_data ASSIGNING FIELD-SYMBOL(<ls_row>).

      " Cast the generic row to our concrete view structure so we can address
      " fields by name.
      ASSIGN <ls_row> TO FIELD-SYMBOL(<ls_typed>) CASTING TYPE zc_tb_glaccount.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      DATA(ls_key) = VALUE ty_key( company_code = <ls_typed>-companycode
                                   layer_id     = <ls_typed>-layerid ).

      " --------------------------------------------------------------------
      " CACHING - the same optimisation as the `rateCache` Map in
      " srv/tax-service.js, and for the same reason.
      "
      " A page of 30 G/L accounts all share one company/layer. Reading the tax
      " rates once per row would mean 30 identical SELECTs.
      "
      " "SELECT inside a LOOP" is THE classic ABAP performance sin. Every code
      " review will flag it. The two accepted fixes are: cache like this, or
      " read everything up front with SELECT ... FOR ALL ENTRIES.
      " --------------------------------------------------------------------
      READ TABLE lt_rate_cache
           INTO DATA(ls_cached)
           WITH KEY company_code = ls_key-company_code
                    layer_id     = ls_key-layer_id.

      IF sy-subrc <> 0.
        ls_cached = VALUE #( company_code   = ls_key-company_code
                             layer_id       = ls_key-layer_id
                             effective_rate = get_effective_rate( ls_key ) ).
        INSERT ls_cached INTO TABLE lt_rate_cache.
      ENDIF.

      <ls_typed>-calculatedamount = zcl_tb_tax_calculator=>calculate_amount(
                                      iv_balance = <ls_typed>-balanceamount
                                      iv_rate    = ls_cached-effective_rate ).

    ENDLOOP.

  ENDMETHOD.


  METHOD get_effective_rate.

    " ------------------------------------------------------------------------
    " OPEN SQL - ABAP's own SQL dialect.
    "
    " Differences from plain SQL worth noticing:
    "   * the field list comes after SELECT, then FROM, then WHERE - but modern
    "     ABAP SQL requires the escape character @ in front of every ABAP
    "     variable, so the compiler can tell host variables from columns
    "   * INTO TABLE @DATA(lt_x) declares the target table inline
    "   * the client field is added automatically; never write it yourself
    " ------------------------------------------------------------------------
    SELECT rate_type, rate_value
      FROM ztb_taxrate
      WHERE company_code = @is_key-company_code
        AND layer_id     = @is_key-layer_id
      INTO TABLE @DATA(lt_rates).

    rv_effective_rate = zcl_tb_tax_calculator=>get_effective_rate(
                          CORRESPONDING #( lt_rates ) ).

  ENDMETHOD.

ENDCLASS.


"!*****************************************************************************
"! *** THE DRAFT PROBLEM - the same trap we hit in CAP ***
"!
"! The SELECT above reads ZTB_TAXRATE, the ACTIVE table. So while the user is
"! editing a draft on Tab 1, Tab 2 would keep showing the last SAVED rates.
"!
"! This is exactly the bug we found and fixed in srv/tax-service.js, where CAP
"! silently redirects queries to `...CompanyLayers.drafts`. In ABAP nothing is
"! silent: you must decide yourself which table to read.
"!
"! The correct RAP way is NOT to add `SELECT FROM ztb_taxrate_d`. Reading a draft
"! table directly is discouraged - the rows there are not necessarily consistent,
"! and you would bypass the framework's transactional buffer.
"!
"! Instead you use the EML (Entity Manipulation Language) READ statement, which
"! asks RAP for the data and lets RAP decide whether the answer comes from the
"! active table, the draft table, or the in-memory transactional buffer:
"!
"!     READ ENTITIES OF zi_tb_companylayer
"!       ENTITY CompanyLayer BY \_TaxRate
"!         ALL FIELDS WITH VALUE #( ( CompanyCode = is_key-company_code
"!                                    LayerID     = is_key-layer_id
"!                                    %is_draft   = if_abap_behv=>mk-on ) )
"!         RESULT DATA(lt_rates).
"!
"! Note `%is_draft` - RAP's explicit version of the IsActiveEntity flag that CAP
"! resolved behind our backs. The `%` prefix marks RAP's own control fields
"! (%key, %cid, %is_draft, %control, %msg ...).
"!
"! EML is the ABAP API for talking to business objects: READ ENTITIES,
"! MODIFY ENTITIES, COMMIT ENTITIES. It is how one BO calls another, and how a
"! report or a job manipulates a RAP object. Worth learning early - it replaces
"! the direct SELECT/UPDATE habits of classic ABAP.
"!*****************************************************************************
