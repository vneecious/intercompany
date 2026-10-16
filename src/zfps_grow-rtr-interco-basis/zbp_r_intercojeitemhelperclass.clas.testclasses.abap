*"* use this source file for your ABAP unit test classes
class ltcl_test definition final for testing
  duration short
  risk level harmless.

  private section.
    methods:
      call_apply_rules for testing raising cx_static_check.
endclass.


class ltcl_test implementation.

  method call_apply_rules.

    modify entities of zr_intercojeitemhelperclass
        entity Header
            execute ApplyRules
            from value #( (
                          CompanyCode  = 'MLA'
                          FiscalPeriod = '001'
                          FiscalYear   = '2024'
                          Ledger       = '0L'
                          PaymentType  = 'E'
                          ) ).

    commit entities.
  endmethod.

endclass.
