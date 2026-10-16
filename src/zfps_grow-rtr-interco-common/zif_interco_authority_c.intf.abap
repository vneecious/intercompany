interface zif_interco_authority_c
  public .


  constants:
    begin of permission,
      create  type activ_auth value '01',
      update  type activ_auth value '02',
      display type activ_auth value '03',
      delete  type activ_auth value '06',
    end of permission.


endinterface.
