"!*****************************************************************************
"! ZBP_I_TB_COMPANYLAYER — the behavior implementation class ("behavior pool")
"!
"! This is the class named in the behavior definition:
"!     managed implementation in class zbp_i_tb_companylayer unique;
"!
"! Because our BO is MANAGED, RAP already does all the create/update/delete and
"! all the draft handling. This class therefore contains only the extras we
"! declared in the .bdef - here, one validation.
"!
"! COMPARE WITH: srv/tax-service.js. Both files are "the place where framework
"! hooks live". The mapping of concepts:
"!
"!     RAP                       CAP (Node.js)
"!     ------------------------  --------------------------------------------
"!     validation ... on save    this.before(['CREATE','UPDATE'], E, req => …)
"!     determination ... on save this.before('SAVE', E, …) / after
"!     action                    this.on('actionName', …)
"!     READ ENTITIES (EML)       SELECT.from(…)
"!     %msg / reported           req.error(…) / req.warn(…)
"!
"! ABAP SYNTAX NOTE
"! ----------------
"! `CLASS ... DEFINITION FOR BEHAVIOR OF <bdef>` is a special class flavour. Its
"! methods are declared in a `PRIVATE SECTION` with `FOR VALIDATE ON SAVE`,
"! `FOR DETERMINE ON SAVE`, `FOR MODIFY` and so on - the compiler matches them
"! against the behavior definition and complains if they disagree.
"!
"! The local class name is always `lhc_<alias>` (local handler class).
"!*****************************************************************************
CLASS lhc_taxrate DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    "! Checks that every tax rate the user entered is sensible.
    "!
    "! The signature is fixed by RAP:
    "!   IMPORTING keys      - the rows to validate (keys only)
    "!   CHANGING  failed    - which rows must block the save
    "!   CHANGING  reported  - the messages to show the user
    METHODS validateRateValue FOR VALIDATE ON SAVE
      IMPORTING keys FOR TaxRate~validateRateValue.

ENDCLASS.


CLASS lhc_taxrate IMPLEMENTATION.

  METHOD validateRateValue.

    " ------------------------------------------------------------------------
    " STEP 1 - read the data.
    "
    " `keys` contains only the KEYS of the affected rows, never the data. This
    " is deliberate: RAP wants you to fetch exactly what you need, once, as a
    " set - not row by row.
    "
    " READ ENTITIES is EML (Entity Manipulation Language). Crucially it reads
    " through the RAP layer, so it returns the DRAFT values the user is
    " currently typing, not the last-saved ones. That is the difference
    " discussed at the bottom of ZCL_TB_GLACC_VE.clas.abap.
    " ------------------------------------------------------------------------
    READ ENTITIES OF zi_tb_companylayer IN LOCAL MODE
      ENTITY TaxRate
        FIELDS ( RateType RateValue )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_rates).

    " ------------------------------------------------------------------------
    " STEP 2 - check each row and collect problems.
    " ------------------------------------------------------------------------
    LOOP AT lt_rates INTO DATA(ls_rate).

      DATA(lv_error_text) = VALUE string( ).

      IF ls_rate-RateType IS INITIAL.
        lv_error_text = 'Rate type must not be empty'.

      ELSEIF ls_rate-RateValue IS INITIAL.
        lv_error_text = 'Rate value must not be zero'.

      ELSEIF ls_rate-RateValue < 0.
        lv_error_text = 'Rate value must not be negative'.

      ELSEIF ls_rate-RateValue > 100.
        " A single rate above 100% is almost certainly a typo (someone typing
        " 1900 instead of 19.00). Worth blocking.
        lv_error_text = 'Rate value must not exceed 100%'.
      ENDIF.

      IF lv_error_text IS NOT INITIAL.

        " ------------------------------------------------------------------
        " `failed` marks the row as invalid -> the save is refused.
        " ------------------------------------------------------------------
        APPEND VALUE #( %tky = ls_rate-%tky )
               TO failed-taxrate.

        " ------------------------------------------------------------------
        " `reported` carries the message back to the UI. Fiori Elements shows
        " it in the message popover AND highlights the offending field in red,
        " because we name the element in %element.
        "
        " %tky = "transactional key" - the key plus the draft indicator. Using
        " %tky instead of %key is what makes the message attach to the right
        " draft row.
        "
        " In production you would raise a proper message from a message class
        " (T100) rather than a hard-coded string, so it can be translated:
        "     %msg = new_message( id = 'ZTB' number = '001' severity = ... )
        " ------------------------------------------------------------------
        APPEND VALUE #( %tky     = ls_rate-%tky
                        %element-RateValue = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = lv_error_text ) )
               TO reported-taxrate.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.


"!*****************************************************************************
"! WHAT ELSE COULD LIVE IN THIS CLASS
"!
"! A DETERMINATION - logic that FILLS fields automatically, rather than checking
"! them. Declared in the .bdef as:
"!     determination setDefaultRate on modify { create; }
"! Typical uses: default a value, derive a field from another, renumber items.
"!
"! An ACTION - a button in the UI that does something to the object. Declared as:
"!     action ( features : instance ) copyRatesFromPreviousLayer result [1] $self;
"! It would appear in the Fiori toolbar with no UI coding at all - the ABAP
"! equivalent of an unbound/bound action in CAP.
"!
"! FEATURE CONTROL - making fields or buttons dynamically read-only/hidden:
"!     methods get_instance_features for instance features importing keys for …
"! e.g. "the rate table is read-only once the period is closed".
"! The CAP counterpart is @Common.FieldControl bound to a field, or an
"! `after READ` handler that sets a control value.
"!
"! AUTHORIZATION - `get_instance_authorizations`, where you would check the
"! user's authorization object for the company code (AUTHORITY-CHECK OBJECT
"! 'F_BKPF_BUK'). This is the part every real finance app must implement and
"! that we skipped entirely, in both stacks.
"!*****************************************************************************
