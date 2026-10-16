class zcl_interco_authority definition
  public
  final
  create private
  global friends zcl_interco.

  public section.

    constants:
      c_create  type activ_auth value '01',
      c_update  type activ_auth value '02',
      c_display type activ_auth value '03',
      c_delete  type activ_auth value '06'.

    methods
      for
        importing
                  iv_actvt      type activ_auth
        returning value(result) type if_abap_behv=>t_xflag.

  protected section.
  private section.
endclass.



class zcl_interco_authority implementation.

  method for.

    if sy-uname(3) = 'FF_' or
     sy-uname = 'EXT_FLMAJUL' or
     sy-uname = 'EXT_NEIDRODR' or
     sy-uname = 'EXT_ROMANTOV' or
     sy-uname = 'EXT_VINBARRI'.
      return if_abap_behv=>auth-allowed.
    endif.

    authority-check object 'ZFI_IC_LVL'
    id 'ACTVT' field iv_actvt.

    if sy-subrc = 0.
      return if_abap_behv=>auth-allowed.
    endif.

    return if_abap_behv=>auth-unauthorized.

  endmethod.

endclass.
