@EndUserText.label: 'Interco P&L MT005 flatten (AMDP, raw tables)'
define table function ZI_IntercoMT005PnLAmdp
  with parameters
    @Environment.systemField : #CLIENT
    clnt : abap.clnt
  returns {
    client               : abap.clnt;
    zconsolidation       : zfi_dte_consolidation;
    zagrup_cuentas       : zfi_dte_agrup_ctas;
    l5                   : nodetxt;
    idl5                 : hrynode;
    l4                   : nodetxt;
    idl4                 : hrynode;
    l3                   : nodetxt;
    idl3                 : hrynode;
    l2                   : nodetxt;
    idl2                 : hrynode;
    l1                   : nodetxt;
    idl1                 : hrynode;
    l0                   : nodetxt;
    idl0                 : hrynode;
    count_zagrup_cuentas : abap.int4;
    temp_zagrup_cuentas  : abap.char( 6 );
  }
  implemented by method zcl_interco_mt005_pnl=>get_pnl;
