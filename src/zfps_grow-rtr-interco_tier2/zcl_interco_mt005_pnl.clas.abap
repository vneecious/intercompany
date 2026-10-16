CLASS zcl_interco_mt005_pnl DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_amdp_marker_hdb.
    CLASS-METHODS get_pnl FOR TABLE FUNCTION zi_intercomt005pnlamdp.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zcl_interco_mt005_pnl IMPLEMENTATION.

  METHOD get_pnl BY DATABASE FUNCTION FOR HDB
                 LANGUAGE SQLSCRIPT
                 OPTIONS READ-ONLY
                 USING zfi_t_mt005 hrrp_nodet.

    RETURN
      SELECT :clnt                          AS client,
             mt005.zconsolidation           AS zconsolidation,
             mt005.zagrup_cuentas           AS zagrup_cuentas,
             l5.nodetxt AS l5, l5.hrynode AS idl5,
             l4.nodetxt AS l4, l4.hrynode AS idl4,
             l3.nodetxt AS l3, l3.hrynode AS idl3,
             l2.nodetxt AS l2, l2.hrynode AS idl2,
             l1.nodetxt AS l1, l1.hrynode AS idl1,
             l0.nodetxt AS l0, l0.hrynode AS idl0,
             LENGTH( mt005.zagrup_cuentas ) AS count_zagrup_cuentas,
             '0' || mt005.zagrup_cuentas    AS temp_zagrup_cuentas
        FROM zfi_t_mt005 AS mt005
        INNER JOIN hrrp_nodet AS l5
          ON  l5.mandt = :clnt AND l5.hryid = 'H109/MLIB/ZPYL' AND l5.spras = 'S'
          AND l5.hryvalto = '99991231' AND l5.hrynode = mt005.zpl5
        INNER JOIN hrrp_nodet AS l4
          ON  l4.mandt = :clnt AND l4.hryid = 'H109/MLIB/ZPYL' AND l4.spras = 'S'
          AND l4.hryvalto = '99991231' AND l4.hrynode = l5.parnode
        INNER JOIN hrrp_nodet AS l3
          ON  l3.mandt = :clnt AND l3.hryid = 'H109/MLIB/ZPYL' AND l3.spras = 'S'
          AND l3.hryvalto = '99991231' AND l3.hrynode = l4.parnode
        INNER JOIN hrrp_nodet AS l2
          ON  l2.mandt = :clnt AND l2.hryid = 'H109/MLIB/ZPYL' AND l2.spras = 'S'
          AND l2.hryvalto = '99991231' AND l2.hrynode = l3.parnode
        INNER JOIN hrrp_nodet AS l1
          ON  l1.mandt = :clnt AND l1.hryid = 'H109/MLIB/ZPYL' AND l1.spras = 'S'
          AND l1.hryvalto = '99991231' AND l1.hrynode = l2.parnode
        INNER JOIN hrrp_nodet AS l0
          ON  l0.mandt = :clnt AND l0.hryid = 'H109/MLIB/ZPYL' AND l0.spras = 'S'
          AND l0.hryvalto = '99991231' AND l0.hrynode = l1.parnode
       WHERE mt005.mandt = :clnt;

  ENDMETHOD.

ENDCLASS.
