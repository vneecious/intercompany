REPORT zreing_op_type.
INCLUDE lsvcmcod.

FORM update_timestamp. "nome ilustrativo; use o FORM do evento gerado no include do cluster

  DATA: lv_error  TYPE c,
        lv_cnt    TYPE i.

  " 3) Preparar acesso às tabelas internas do subobjeto
  "    SUBOBJ = nome técnico do subobjeto no cluster (igual ao usado em SE54)
  DATA(lv_subobj) = CONV vclstruc-object( 'ZREING_OP_TYP_CV' ). " <-- troque pelo seu subobjeto: ex. 'ZV_REING_OP_TYPE'

  FIELD-SYMBOLS:
    <row> TYPE any,
    <entry> type zreing_op_typ_cv.

  PERFORM vcl_set_table_access_for_obj USING lv_subobj
                                       CHANGING lv_error.
  IF lv_error IS NOT INITIAL.
    RETURN.
  ENDIF.

  " 5) Percorrer o TOTAL (linhas já marcadas para gravação)
  CLEAR lv_cnt.
  LOOP AT <vcl_total> ASSIGNING <row>.
    assign <row> to <entry> CASTING.

    PERFORM edit_view_entry(SAPLZREING_OP_TYPE)
      TABLES <vcl_extract> <vcl_total> <vcl_header> <vcl_namtab> <vcl_dpl_sellist>
      USING  <entry> 'UPD'.

    lv_cnt = lv_cnt + 1.
  ENDLOOP.

  " 6) Se TOTAL estiver vazio, varrer o EXTRACT (registros atuais) e marcar para update
  IF lv_cnt = 0.
    LOOP AT <vcl_extract> ASSIGNING <row>.
      ASSIGN <row> TO <entry> CASTING.

      PERFORM edit_view_entry(SAPLZREING_OP_TYPE)
        TABLES <vcl_extract> <vcl_total> <vcl_header> <vcl_namtab> <vcl_dpl_sellist>
        USING  <entry> 'UPD'.
    ENDLOOP.
  ENDIF.

ENDFORM.
