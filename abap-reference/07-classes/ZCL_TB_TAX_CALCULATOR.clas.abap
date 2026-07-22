"!*****************************************************************************
"! ZCL_TB_TAX_CALCULATOR — the pure business logic
"!
"! COMPARE WITH: the `enrich` and `readEffectiveRate` functions in
"!               srv/tax-service.js
"!
"! DESIGN POINT WORTH COPYING
"! --------------------------
"! This class knows nothing about OData, UIs, drafts or RAP. It takes numbers
"! and returns numbers. That is deliberate:
"!   * it can be unit-tested in milliseconds with no database (see the test
"!     class at the bottom of this file)
"!   * the same logic can be called from the virtual element exit, from a
"!     validation, from a batch job, or from a report
"!
"! Keeping calculation separate from framework plumbing is the single most
"! valuable habit in both ABAP and JavaScript. In our CAP app the equivalent
"! separation is weaker - the maths sits inline in the handler - which is fine
"! for a 3-line formula but would not be for a real tax engine.
"!
"! ABAP SYNTAX NOTES FOR A BEGINNER
"! --------------------------------
"! * A class is split into a DEFINITION (the interface: what exists) and an
"!   IMPLEMENTATION (the code). Both live in the same file.
"! * Visibility sections: PUBLIC / PROTECTED / PRIVATE. Order is fixed.
"! * CLASS-METHODS = static methods. METHODS = instance methods.
"! * IMPORTING = input parameters, EXPORTING = output, RETURNING = a single
"!   return value (only one allowed, and it makes the method usable in
"!   expressions like `x = zcl_...=>method( ... )`).
"! * `"` starts a comment. `"!` starts ABAPDoc, which shows up on hover in ADT.
"!*****************************************************************************
CLASS zcl_tb_tax_calculator DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! One tax rate row, as far as the calculation is concerned.
    TYPES: BEGIN OF ty_rate,
             rate_type  TYPE ztb_rate_type,
             rate_value TYPE ztb_rate_value,
           END OF ty_rate.

    "! A table of rates.
    "! WITH EMPTY KEY means "no key, I only ever loop over it" - the correct
    "! choice here, and it avoids ABAP's default STANDARD-key trap.
    TYPES ty_rates TYPE STANDARD TABLE OF ty_rate WITH EMPTY KEY.

    "! Adds up all rate values into one effective percentage.
    "!
    "! @parameter it_rates | the rates the user entered on Tab 1
    "! @parameter rv_effective_rate | e.g. 19.00 + 5.50 = 24.50
    CLASS-METHODS get_effective_rate
      IMPORTING it_rates                 TYPE ty_rates
      RETURNING VALUE(rv_effective_rate) TYPE ztb_rate_value.

    "! Applies a percentage to a balance.
    "!
    "! @parameter iv_balance | the G/L account balance
    "! @parameter iv_rate    | the effective percentage, e.g. 24.50
    "! @parameter rv_amount  | balance * rate / 100, rounded to 2 decimals
    CLASS-METHODS calculate_amount
      IMPORTING iv_balance       TYPE ztb_amount
                iv_rate          TYPE ztb_rate_value
      RETURNING VALUE(rv_amount) TYPE ztb_amount.

ENDCLASS.


CLASS zcl_tb_tax_calculator IMPLEMENTATION.

  METHOD get_effective_rate.

    " ------------------------------------------------------------------------
    " THE SIMPLE SUM - and the caveat, flagged as the project brief asked.
    "
    " We add the rates together (VAT 19% + surcharge 5.5% = 24.5%) and apply the
    " total. That is what the brief specified, but be aware it is not how a real
    " German Solidaritaetszuschlag works: a surcharge is levied on the TAX, not
    " on the base, which would give 19% + (19% * 5.5%) = 20.045%.
    "
    " Kept simple on purpose - the goal is to learn where logic lives, not tax law.
    " ------------------------------------------------------------------------

    " REDUCE is ABAP's fold/reduce expression (available since 7.40). The older
    " and equally correct way is:
    "     LOOP AT it_rates INTO DATA(ls_rate).
    "       rv_effective_rate = rv_effective_rate + ls_rate-rate_value.
    "     ENDLOOP.
    " Both are fine. REDUCE is preferred in modern ABAP because the result
    " variable cannot accidentally be modified elsewhere in the loop.
    rv_effective_rate = REDUCE ztb_rate_value(
                          INIT total = CONV ztb_rate_value( 0 )
                          FOR  ls_rate IN it_rates
                          NEXT total = total + ls_rate-rate_value ).

  ENDMETHOD.


  METHOD calculate_amount.

    " Guard clause: no rates entered means nothing to calculate.
    " Note `IS INITIAL` - ABAP's way of saying "is the type's default value"
    " (0 for numbers, '' for strings, empty for tables). There is no NULL.
    IF iv_rate IS INITIAL.
      rv_amount = 0.
      RETURN.
    ENDIF.

    " ------------------------------------------------------------------------
    " THE CALCULATION.
    "
    " The result is the TAX AMOUNT (balance x rate), not the gross amount. For
    " the gross you would write:  iv_balance * ( 1 + iv_rate / 100 ).
    "
    " ROUNDING: ztb_amount is DEC(15,2), so ABAP would round on assignment
    " anyway - but doing it explicitly documents the intent and lets you choose
    " the mode. Financial code should never rely on implicit rounding.
    "
    " Watch the SPACES around parentheses and operators: ABAP requires them.
    "     a = ( b + c ) / 100.     " correct
    "     a = (b+c)/100.           " syntax error
    " This catches every ABAP beginner at least once.
    " ------------------------------------------------------------------------
    rv_amount = round( val = iv_balance * iv_rate / 100
                       dec = 2 ).

  ENDMETHOD.

ENDCLASS.


"!*****************************************************************************
"! THE UNIT TEST CLASS
"!
"! ABAP Unit is built into the language and the IDE - no library to install.
"! In ADT you run these with Ctrl+Shift+F10.
"!
"! `FOR TESTING` marks the class as a test. `RISK LEVEL HARMLESS` promises it
"! touches no persistent data, which is what lets it run in any system.
"! `DURATION SHORT` is a hint that it takes under a minute.
"!
"! In a real repository this class sits in the "Test Classes" tab of
"! ZCL_TB_TAX_CALCULATOR, not in a separate file.
"!
"! The CAP equivalent would be a test file using `cds.test` + jest/mocha. We did
"! not write one for this learning project - but the calculation in
"! srv/tax-service.js is exactly the kind of thing that deserves one.
"!*****************************************************************************
CLASS ltcl_tax_calculator DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS sums_multiple_rates      FOR TESTING.
    METHODS empty_table_gives_zero   FOR TESTING.
    METHODS applies_rate_to_balance  FOR TESTING.
    METHODS handles_negative_balance FOR TESTING.
    METHODS rounds_to_two_decimals   FOR TESTING.

ENDCLASS.


CLASS ltcl_tax_calculator IMPLEMENTATION.

  METHOD sums_multiple_rates.

    " VALUE #( ) is the constructor expression for building an internal table
    " inline. The `#` means "infer the type from the context".
    DATA(lt_rates) = VALUE zcl_tb_tax_calculator=>ty_rates(
      ( rate_type = 'VAT Standard'         rate_value = '19.00' )
      ( rate_type = 'Solidarity Surcharge' rate_value = '5.50'  ) ).

    " cl_abap_unit_assert is the assertion library. `act` = actual,
    " `exp` = expected, `msg` = what to print when it fails.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_tb_tax_calculator=>get_effective_rate( lt_rates )
      exp = CONV ztb_rate_value( '24.50' )
      msg = '19.00 + 5.50 should give an effective rate of 24.50' ).

  ENDMETHOD.


  METHOD empty_table_gives_zero.

    cl_abap_unit_assert=>assert_initial(
      act = zcl_tb_tax_calculator=>get_effective_rate( VALUE #( ) )
      msg = 'No rates entered must give an effective rate of zero' ).

  ENDMETHOD.


  METHOD applies_rate_to_balance.

    " This is the exact case we verified against the running CAP service:
    " 1,250,000.00 EUR at 24.5% = 306,250.00
    cl_abap_unit_assert=>assert_equals(
      act = zcl_tb_tax_calculator=>calculate_amount(
              iv_balance = CONV ztb_amount( '1250000.00' )
              iv_rate    = CONV ztb_rate_value( '24.50' ) )
      exp = CONV ztb_amount( '306250.00' )
      msg = '1,250,000.00 at 24.5% should be 306,250.00' ).

  ENDMETHOD.


  METHOD handles_negative_balance.

    " Revenue and payable accounts carry credit (negative) balances in our data,
    " so the calculation must not assume a positive input.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_tb_tax_calculator=>calculate_amount(
              iv_balance = CONV ztb_amount( '-517900.25' )
              iv_rate    = CONV ztb_rate_value( '24.50' ) )
      exp = CONV ztb_amount( '-126885.56' )
      msg = 'Credit balances must calculate correctly too' ).

  ENDMETHOD.


  METHOD rounds_to_two_decimals.

    " 842,300.50 * 24.5% = 206,363.6225 -> must round to 206,363.62
    cl_abap_unit_assert=>assert_equals(
      act = zcl_tb_tax_calculator=>calculate_amount(
              iv_balance = CONV ztb_amount( '842300.50' )
              iv_rate    = CONV ztb_rate_value( '24.50' ) )
      exp = CONV ztb_amount( '206363.62' )
      msg = 'Result must be rounded to 2 decimal places' ).

  ENDMETHOD.

ENDCLASS.
