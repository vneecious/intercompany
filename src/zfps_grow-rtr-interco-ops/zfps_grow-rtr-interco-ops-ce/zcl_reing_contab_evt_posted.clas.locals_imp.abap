*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations

CLASS lhe_posted DEFINITION INHERITING FROM cl_abap_behavior_event_handler.
  PRIVATE SECTION.
    METHODS on_posted FOR ENTITY EVENT
      it_posted FOR ZI_ReingCARun~Posted.
ENDCLASS.

CLASS lhe_posted IMPLEMENTATION.
  METHOD on_posted.
    " CON-08 / ET 8b: por cada ANT recien contabilizado (evento Posted),
    " regenerar su AN2 llamando al regenerador de CA.
    LOOP AT it_posted INTO DATA(ls_event).

      " Early exit: solo los ANT disparan regeneracion de AN2.
      IF ls_event-%param-OpType <> 'ANT'.
        CONTINUE.
      ENDIF.

      " CalcRunId viaja en la key del evento (CalcRun); LineNum+OpType en %param.
      DATA(ls_result) = zcl_reing_ca_an2_regenerator=>regenerate(
        iv_origin_run_id   = ls_event-CalcRunId
        iv_origin_line_num = ls_event-%param-LineNum ).

      " (B) RESUELTO (Carlos 06/08): regenerate() ya NO hace commit propio;
      "     el commit lo arrastra el save sequence RAP de Post/Storno que
      "     contiene a este handler. NO agregar cl_abap_tx=>save() aqui.

      IF ls_result-success = abap_false.
        " (C) TODO: log de ls_result-message (handler async, sin response params).
      ENDIF.

    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
