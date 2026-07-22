/******************************************************************************
 * srv/annotations.cds  —  THE USER INTERFACE, DESCRIBED AS DATA
 *
 * READ THIS FILE SLOWLY. It is the heart of "Fiori Elements".
 *
 * THE BIG IDEA
 * ------------
 * In a normal web app you write HTML/JS: "put a table here, with these columns".
 * In Fiori Elements you write NOTHING of the kind. Instead you attach
 * ANNOTATIONS to your data model - little labelled facts like
 *
 *      "these two fields belong in the filter bar"
 *      "these four fields are the columns of the table"
 *      "this entity's detail screen has two tabs"
 *
 * ...and SAP's ready-made templates (sap.fe.templates.ListReport and
 * sap.fe.templates.ObjectPage) read those annotations at runtime and BUILD the
 * screen for you. That is what "metadata-driven UI" means.
 *
 * Why SAP does this: 40,000 SAP screens that all look, filter, sort, export,
 * and behave identically, and that all get new platform features (like the new
 * table personalisation dialog) for free, without touching app code.
 *
 * WHERE DO ANNOTATIONS LIVE?
 * --------------------------
 * They can live in the backend (here) or in the frontend app. We put them in
 * the BACKEND on purpose, because that is what a real S/4HANA project does, and
 * it makes the ABAP comparison exact:
 *
 *   this file                    <->  a "Metadata Extension" in ABAP: a .ddlx
 *                                     file annotating a ZC_* view.
 *                                     See ../abap-reference/04-metadata-extension/
 *
 * These annotations are shipped to the browser inside $metadata. Open
 * http://localhost:4004/odata/v4/tax-balance/$metadata and search for
 * "UI.LineItem" - you will find what you write below, in XML form.
 *
 * THE VOCABULARY
 * --------------
 * `UI`, `Common`, `Capabilities` are "vocabularies" - standard dictionaries of
 * annotation terms published by SAP/OASIS. `UI.LineItem` means "the term
 * LineItem from the UI vocabulary". Its real full name is
 * com.sap.vocabularies.UI.v1.LineItem, which you will see in $metadata and in
 * the manifest. ABAP CDS uses the same terms, written as @UI.lineItem.
 ******************************************************************************/

using TaxBalanceService as service from './tax-service';


/*============================================================================*
 * PART 1 - SCREEN 1: THE LIST REPORT (the "entry gate")
 *
 * Floorplan: List Report. A List Report is always: a filter bar on top, a
 * table below, and clicking a row navigates somewhere.
 *============================================================================*/

annotate service.CompanyLayers with @(

  // ---- HeaderInfo -----------------------------------------------------------
  // Names the object in human words. Fiori Elements uses these strings in the
  // page title, in the "1 of 6" counter, in delete confirmation popups, etc.
  UI.HeaderInfo: {
    $Type         : 'UI.HeaderInfoType',
    TypeName      : 'Company Code / Layer',
    TypeNamePlural: 'Company Codes / Layers',
    // Title/Description appear as the big heading of the Object Page (Screen 2).
    Title         : { $Type: 'UI.DataField', Value: company.name },
    Description   : { $Type: 'UI.DataField', Value: layer.description }
  },

  // ---- SelectionFields ------------------------------------------------------
  // *** THIS LINE CREATES SCREEN 1'S TWO DROPDOWNS. ***
  // Every field listed here becomes a filter field in the filter bar. That is
  // the entire implementation of "the user must select Company Code and Layer".
  // ABAP CDS equivalent, written on the ZC_ view:  @UI.selectionField: [{ position: 10 }]
  UI.SelectionFields: [ companyCode, layerID ],

  // ---- LineItem -------------------------------------------------------------
  // The columns of the table. Order here = order on screen.
  // ABAP CDS equivalent: @UI.lineItem: [{ position: 10, label: '...' }]
  UI.LineItem: [
    { $Type: 'UI.DataField', Value: companyCode,          ![@UI.Importance]: #High },
    { $Type: 'UI.DataField', Value: layerID,              ![@UI.Importance]: #High },
    // A path across an association: "follow `company`, then take `countryCode`".
    // Fiori Elements turns this into $expand=company in the OData request for us.
    { $Type: 'UI.DataField', Value: company.countryCode,  Label: 'Country' },
    { $Type: 'UI.DataField', Value: company.country.name, Label: 'Country Name' }
  ],

  // ---- Facets ---------------------------------------------------------------
  // *** THIS CREATES SCREEN 2'S TWO TABS. ***
  //
  // A "facet" is a section of the Object Page. There are two kinds:
  //   - ReferenceFacet  : shows ONE thing (a field group, or a table)
  //   - CollectionFacet : a container holding several ReferenceFacets
  //
  // Each TOP-LEVEL facet becomes one tab, because the manifest sets
  // "sectionLayout": "Tabs". Change that to "Page" and the very same
  // annotations render as one long scrollable page instead. Nothing else
  // changes. That is the power of metadata-driven UI.
  //
  // ABAP CDS equivalent: @UI.facet: [{ id, purpose, type: #COLLECTION, ... }]
  UI.Facets: [

    // ---------- TAB 1 : Tax Rates ----------
    {
      $Type : 'UI.CollectionFacet',
      ID    : 'TaxRatesTab',
      Label : 'Tax Rates',
      Facets: [
        // Sub-section A: show which country we are in (a plain field group).
        {
          $Type : 'UI.ReferenceFacet',
          ID    : 'CountryContextFacet',
          Label : 'Selection Context',
          // "Target" points at another annotation, by name. '@UI.FieldGroup#CountryInfo'
          // means "the FieldGroup annotation with qualifier CountryInfo, on THIS entity".
          Target: '@UI.FieldGroup#CountryInfo'
        },
        // Sub-section B: the editable table of tax rates.
        // The target crosses an association: "go to taxRates, use ITS LineItem".
        // Because taxRates is a COMPOSITION, Fiori Elements makes this table
        // editable (add / delete rows) once the user presses Edit.
        {
          $Type : 'UI.ReferenceFacet',
          ID    : 'TaxRatesTableFacet',
          Label : 'Tax Rate Entries',
          Target: 'taxRates/@UI.LineItem'
        }
      ]
    },

    // ---------- TAB 2 : Balance Sheet Comparison ----------
    {
      $Type : 'UI.CollectionFacet',
      ID    : 'BalanceSheetTab',
      Label : 'Balance Sheet Comparison',
      Facets: [
        {
          $Type : 'UI.ReferenceFacet',
          ID    : 'GLAccountsTableFacet',
          Label : 'G/L Accounts',
          Target: 'glAccounts/@UI.LineItem'
        }
      ]
    }
  ],

  // ---- HeaderFacets ---------------------------------------------------------
  // Facets shown in the blue-grey header area ABOVE the tabs, so they stay
  // visible whichever tab you are on. Good place for "which selection am I in".
  UI.HeaderFacets: [
    { $Type: 'UI.ReferenceFacet', ID: 'HeaderContext', Target: '@UI.FieldGroup#HeaderInfo' }
  ],

  // ---- FieldGroups ----------------------------------------------------------
  // A FieldGroup is just a named list of fields. On its own it renders nothing;
  // it renders where a Facet points at it. The `#CountryInfo` part is a
  // "qualifier" - it is how you have several FieldGroups on one entity and tell
  // them apart.
  UI.FieldGroup #CountryInfo: {
    $Type: 'UI.FieldGroupType',
    Data : [
      { $Type: 'UI.DataField', Value: companyCode,          Label: 'Company Code' },
      { $Type: 'UI.DataField', Value: company.name,         Label: 'Company Name' },
      { $Type: 'UI.DataField', Value: company.countryCode,  Label: 'Country Key'  },
      { $Type: 'UI.DataField', Value: company.country.name, Label: 'Country'      },
      { $Type: 'UI.DataField', Value: layerID,              Label: 'Layer'        },
      { $Type: 'UI.DataField', Value: layer.description,    Label: 'Layer Description' }
    ]
  },

  UI.FieldGroup #HeaderInfo: {
    $Type: 'UI.FieldGroupType',
    Data : [
      { $Type: 'UI.DataField', Value: company.country.name, Label: 'Country' },
      { $Type: 'UI.DataField', Value: layer.description,    Label: 'Layer'   }
    ]
  }
);


/*============================================================================*
 * PART 2 - VALUE HELP (the F4 dropdowns on the filter bar)
 *
 * Without this, Company Code would be a plain text box and the user would have
 * to KNOW that '1000' exists. With it, they get a searchable dropdown.
 *
 * Note the syntax difference: `annotate X with @(...)` annotates the ENTITY,
 * `annotate X with { field @(...) }` annotates individual FIELDS.
 *============================================================================*/

annotate service.CompanyLayers with {

  companyCode @(
    // ---- Common.Text + TextArrangement -------------------------------------
    // "When you display companyCode, the human-readable text for it lives in
    //  company.name". TextArrangement then says how to combine them:
    //     #TextFirst  -> "Musterhaus GmbH (1000)"
    //     #TextOnly   -> "Musterhaus GmbH"
    //     #TextLast   -> "1000 (Musterhaus GmbH)"
    // You will use this constantly in SAP: keys are for machines, texts for people.
    Common.Text: company.name,
    Common.TextArrangement: #TextFirst,

    // ---- Common.ValueList --------------------------------------------------
    // Describes the popup/dropdown: which entity set to read, and how its
    // columns map to the current field.
    // ABAP CDS equivalent:
    //     @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CompanyCode',
    //                                                    element: 'CompanyCode' } }]
    Common.ValueList: {
      $Type         : 'Common.ValueListType',
      // Which entity set the dropdown reads from. Must be exposed in the service!
      CollectionPath: 'CompanyCodes',
      Label         : 'Company Codes',
      SearchSupported: true,
      Parameters    : [
        // "InOut" = this column both FILLS the field when picked, and FILTERS
        //  the dropdown by whatever is already typed in the field.
        { $Type            : 'Common.ValueListParameterInOut',
          LocalDataProperty: companyCode,   // field in MY entity
          ValueListProperty: 'code' },      // column in CompanyCodes (a string!)
        // "DisplayOnly" = extra columns shown in the popup for context.
        { $Type: 'Common.ValueListParameterDisplayOnly', ValueListProperty: 'name' },
        { $Type: 'Common.ValueListParameterDisplayOnly', ValueListProperty: 'countryCode' }
      ]
    }
  );

  layerID @(
    Common.Text: layer.description,
    Common.TextArrangement: #TextFirst,
    // ValueListWithFixedValues: true means "there are only a handful of options,
    // so render a simple dropdown instead of opening a search dialog".
    Common.ValueListWithFixedValues: true,
    Common.ValueList: {
      $Type         : 'Common.ValueListType',
      CollectionPath: 'Layers',
      Label         : 'Accounting Layers',
      Parameters    : [
        { $Type            : 'Common.ValueListParameterInOut',
          LocalDataProperty: layerID,
          ValueListProperty: 'ID' },
        { $Type: 'Common.ValueListParameterDisplayOnly', ValueListProperty: 'description' }
      ]
    }
  );
}


/*============================================================================*
 * PART 2b - TEXTS FOR THE CODE LISTS THEMSELVES
 *
 * The value help popup shows a column of raw codes ('1000', '01'). Telling the
 * framework which field is the human-readable text for each code lets it render
 * "Musterhaus GmbH (1000)" inside the popup too, and silences the runtime
 * warning "Text Annotation for code is not defined".
 *
 * This is the same Common.Text pattern as above, just applied on the code list
 * entity instead of on the field that references it. Getting into the habit of
 * annotating every key with its text is one of the easiest ways to make an SAP
 * app feel finished.
 *============================================================================*/

annotate service.CompanyCodes with {
  code @( Common.Text: name, Common.TextArrangement: #TextFirst );
}

annotate service.Layers with {
  ID   @( Common.Text: description, Common.TextArrangement: #TextFirst );
}

annotate service.Countries with {
  code @( Common.Text: name, Common.TextArrangement: #TextFirst );
}


/*============================================================================*
 * PART 3 - TAB 1's TABLE: the editable tax rate rows
 *============================================================================*/

annotate service.TaxRates with @(

  UI.HeaderInfo: {
    $Type         : 'UI.HeaderInfoType',
    TypeName      : 'Tax Rate',
    TypeNamePlural: 'Tax Rates',
    Title         : { $Type: 'UI.DataField', Value: rateType }
  },

  // Two editable columns. Because the service does not mark them @readonly and
  // the parent is draft-enabled, Fiori Elements renders real input fields here
  // as soon as the user presses Edit. We wrote zero lines of UI code for that.
  UI.LineItem: [
    { $Type: 'UI.DataField', Value: rateType,  Label: 'Rate Type',      ![@UI.Importance]: #High },
    { $Type: 'UI.DataField', Value: rateValue, Label: 'Rate Value (%)', ![@UI.Importance]: #High }
  ]
);

annotate service.TaxRates with {
  // Hide the technical UUID. It must exist (it is the key, and OData needs it
  // to address a row) but a user should never see it.
  // @UI.Hidden is the standard way; ABAP CDS uses @UI.hidden: true.
  ID @UI.Hidden;

  // The parent link is machinery, not data. Hide it too.
  parent @UI.Hidden;

  // A free-text placeholder to guide the user, since we deliberately did NOT
  // constrain rate types to a fixed list (per the project brief).
  rateType @Common.FieldControl: #Mandatory;
}


/*============================================================================*
 * PART 4 - TAB 2's TABLE: the balance sheet comparison
 *
 * `calculatedAmount` has no database column - it is the virtual field filled by
 * srv/tax-service.js. From the UI's point of view there is no difference at
 * all: it is just another column. That is the point of doing the calculation in
 * the backend.
 *============================================================================*/

annotate service.GLAccounts with @(

  UI.HeaderInfo: {
    $Type         : 'UI.HeaderInfoType',
    TypeName      : 'G/L Account',
    TypeNamePlural: 'G/L Accounts',
    Title         : { $Type: 'UI.DataField', Value: accountName },
    Description   : { $Type: 'UI.DataField', Value: accountNumber }
  },

  UI.LineItem: [
    { $Type: 'UI.DataField', Value: accountNumber,    Label: 'G/L Account',       ![@UI.Importance]: #High },
    { $Type: 'UI.DataField', Value: accountName,      Label: 'Account Name',      ![@UI.Importance]: #High },
    { $Type: 'UI.DataField', Value: balanceAmount,    Label: 'Balance Amount',    ![@UI.Importance]: #High },
    { $Type: 'UI.DataField', Value: calculatedAmount, Label: 'Calculated Amount', ![@UI.Importance]: #High }
  ]
);

annotate service.GLAccounts with {
  // These are in the key (OData requires keys in every response) but showing
  // them as columns would be noise - the user already picked them on Screen 1.
  companyCode @UI.Hidden;
  layerID     @UI.Hidden;
}
