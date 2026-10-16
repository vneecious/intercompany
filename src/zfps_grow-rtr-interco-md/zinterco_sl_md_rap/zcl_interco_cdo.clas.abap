CLASS zcl_interco_cdo DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES:
      gtt_md003 TYPE STANDARD TABLE OF zint_a_md003,
      gtt_md002 TYPE STANDARD TABLE OF zint_a_md002,
      gtt_md001 TYPE STANDARD TABLE OF zint_a_md001.
    CONSTANTS:
      BEGIN OF cs_chdo,
        create TYPE if_chdo_object_tools_rel=>ty_cdchngindh VALUE 'I',
        update TYPE if_chdo_object_tools_rel=>ty_cdchngindh VALUE 'U',
        delete TYPE if_chdo_object_tools_rel=>ty_cdchngindh VALUE 'D',
        md001  TYPE if_chdo_object_tools_rel=>ty_cdobjectv VALUE 'ZINT_A_MD001_CH',
        md002  TYPE if_chdo_object_tools_rel=>ty_cdobjectv VALUE 'ZINT_A_MD002_CH',
        md003  TYPE if_chdo_object_tools_rel=>ty_cdobjectv VALUE 'ZINT_A_MD003_CH',
      END OF cs_chdo.
    METHODS write_md003_chdo
      IMPORTING
        iv_chin     TYPE if_chdo_object_tools_rel=>ty_cdchngindh
        is_data     TYPE zint_a_md003
        is_data_old TYPE zint_a_md003
      EXPORTING
        ev_error    TYPE string.
    METHODS save_md003
      IMPORTING
        iv_chin TYPE if_chdo_object_tools_rel=>ty_cdchngindh
        it_data TYPE gtt_md003.
    METHODS write_md002_chdo
      IMPORTING
        iv_chin     TYPE if_chdo_object_tools_rel=>ty_cdchngindh
        is_data     TYPE zint_a_md002
        is_data_old TYPE zint_a_md002
      EXPORTING
        ev_error    TYPE string.
    METHODS save_md002
      IMPORTING
        iv_chin TYPE if_chdo_object_tools_rel=>ty_cdchngindh
        it_data TYPE gtt_md002.
    METHODS write_md001_chdo
      IMPORTING
        iv_chin     TYPE if_chdo_object_tools_rel=>ty_cdchngindh
        is_data     TYPE zint_a_md001
        is_data_old TYPE zint_a_md001
      EXPORTING
        ev_error    TYPE string.
    METHODS save_md001
      IMPORTING
        iv_chin TYPE if_chdo_object_tools_rel=>ty_cdchngindh
        it_data TYPE gtt_md001.
  PROTECTED SECTION.
  PRIVATE SECTION.

ENDCLASS.



CLASS zcl_interco_cdo IMPLEMENTATION.
  METHOD write_md003_chdo.
    DATA(ls_new_md003) = is_data.
    DATA(lv_chin) = iv_chin.
    IF iv_chin = cs_chdo-update OR iv_chin = cs_chdo-delete.
      DATA(ls_old_md003) = is_data_old.
    ELSEIF iv_chin = cs_chdo-create.
      ls_new_md003-client = sy-mandt.
    ENDIF.
    TRY.
        zcl_zint_a_md003_ch_chdo=>write(
          EXPORTING
            objectid                   = cs_chdo-md003
            utime                      = cl_abap_context_info=>get_system_time( )
            udate                      = cl_abap_context_info=>get_system_date( )
            username                   = sy-uname
            o_zint_a_md003             = ls_old_md003
            n_zint_a_md003             = ls_new_md003
            upd_zint_a_md003           = lv_chin
          IMPORTING
            changenumber               = DATA(lv_changenumber) ).
      CATCH cx_chdo_write_error INTO DATA(lref_write_error).
        ev_error = lref_write_error->get_text( ).
    ENDTRY.

  ENDMETHOD.


  METHOD save_md003.
    IF it_data[] IS INITIAL.
      RETURN.
    ENDIF.
    CASE iv_chin.
      WHEN cs_chdo-create.
        INSERT zint_a_md003 FROM TABLE @it_data.
      WHEN cs_chdo-update.
        MODIFY zint_a_md003 FROM TABLE @it_data.
      WHEN cs_chdo-delete.
        DELETE zint_a_md003 FROM TABLE @it_data.
*        SELECT * FROM zint_a_md003 FOR ALL ENTRIES IN @it_data
*            WHERE uuid = @it_data-uuid
*            INTO TABLE @DATA(lt_data).
*        LOOP AT lt_data ASSIGNING FIELD-SYMBOL(<fs_data>).
*          <fs_data>-isdeleted = abap_true.
*        ENDLOOP.
*        MODIFY zint_a_md003 FROM TABLE @lt_data.
    ENDCASE.
  ENDMETHOD.

  METHOD save_md002.
    IF it_data[] IS INITIAL.
      RETURN.
    ENDIF.
    CASE iv_chin.
      WHEN cs_chdo-create.
        INSERT zint_a_md002 FROM TABLE @it_data.
      WHEN cs_chdo-update.
        MODIFY zint_a_md002 FROM TABLE @it_data.
      WHEN cs_chdo-delete.
        DELETE zint_a_md002 FROM TABLE @it_data.
        "        SELECT * FROM zint_a_md002 FOR ALL ENTRIES IN @it_data
        "            WHERE id = @it_data-id
        "            INTO TABLE @DATA(lt_data).
        "        LOOP AT lt_data ASSIGNING FIELD-SYMBOL(<fs_data>).
        "          <fs_data>-isdeleted = abap_true.
        "        ENDLOOP.
        "        MODIFY zint_a_md002 FROM TABLE @lt_data.
    ENDCASE.
  ENDMETHOD.

  METHOD write_md002_chdo.
    DATA(ls_new_md002) = is_data.
    DATA(lv_chin) = iv_chin.
    IF iv_chin = cs_chdo-update OR iv_chin = cs_chdo-delete.
*      SELECT * FROM zint_a_md002
*          WHERE id = @is_data-id
*          INTO TABLE @DATA(lt_md002).
*      IF sy-subrc EQ 0.
*        DATA(ls_old_md002) = lt_md002[ 1 ].
*      ENDIF.
*      IF iv_chin = cs_chdo-delete.
*              ls_new_md002 = is_data_old
**        ls_new_md002 = ls_old_md002.
*        ls_new_md002-isdeleted = abap_true.
*        lv_chin = cs_chdo-update.
*      ENDIF.
    ELSEIF iv_chin = cs_chdo-create.
      ls_new_md002-client = sy-mandt.
    ENDIF.
    TRY.
        zcl_zint_a_md002_ch_chdo=>write(
          EXPORTING
            objectid                   = cs_chdo-md002
            utime                      = cl_abap_context_info=>get_system_time( )
            udate                      = cl_abap_context_info=>get_system_date( )
            username                   = sy-uname
            o_zint_a_md002             = is_data_old
            n_zint_a_md002             = ls_new_md002
            upd_zint_a_md002           = lv_chin
          IMPORTING
            changenumber               = DATA(lv_changenumber) ).
      CATCH cx_chdo_write_error INTO DATA(lref_write_error).
        ev_error = lref_write_error->get_text( ).
    ENDTRY.

  ENDMETHOD.

  METHOD save_md001.
    IF it_data[] IS INITIAL.
      RETURN.
    ENDIF.
    CASE iv_chin.
      WHEN cs_chdo-create.
        INSERT zint_a_md001 FROM TABLE @it_data.
      WHEN cs_chdo-update.
        MODIFY zint_a_md001 FROM TABLE @it_data.
      WHEN cs_chdo-delete.
        DELETE zint_a_md001 FROM TABLE @it_data.
        "SELECT * FROM zint_a_md001 FOR ALL ENTRIES IN @it_data
        "    WHERE id = @it_data-id
        "    INTO TABLE @DATA(lt_data).
        "LOOP AT lt_data ASSIGNING FIELD-SYMBOL(<fs_data>).
        "  <fs_data>-isdeleted = abap_true.
        "ENDLOOP.
        "MODIFY zint_a_md001 FROM TABLE @lt_data.


    ENDCASE.
  ENDMETHOD.

  METHOD write_md001_chdo.
    DATA(ls_new_md001) = is_data.
    DATA(lv_chin) = iv_chin.
    IF iv_chin = cs_chdo-update OR iv_chin = cs_chdo-delete.
*      SELECT * FROM zint_a_md001
*          WHERE id = @is_data-id
*          INTO TABLE @DATA(lt_md001).
*      IF sy-subrc EQ 0.
*        DATA(ls_old_md001) = lt_md001[ 1 ].
*      ENDIF.
*      IF iv_chin = cs_chdo-delete.
*        ls_new_md001 = ls_old_md001.
*        ls_new_md001-isdeleted = abap_true.
*        lv_chin = cs_chdo-update.
*      ENDIF.
    ELSEIF iv_chin = cs_chdo-create.
      ls_new_md001-mandt = sy-mandt.
    ENDIF.
    TRY.
        zcl_zint_a_md001_ch_chdo=>write(
          EXPORTING
            objectid                   = cs_chdo-md001
            utime                      = cl_abap_context_info=>get_system_time( )
            udate                      = cl_abap_context_info=>get_system_date( )
            username                   = sy-uname
            o_zint_a_md001             = is_data_old
            n_zint_a_md001             = ls_new_md001
            upd_zint_a_md001           = lv_chin
          IMPORTING
            changenumber               = DATA(lv_changenumber) ).
      CATCH cx_chdo_write_error INTO DATA(lref_write_error).
        ev_error = lref_write_error->get_text( ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
