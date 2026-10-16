class zcl_interco_log definition
  public
  final
  create private
  global friends zcl_interco.

  public section.

    types: tt_key_column type table of string with key table_line.

    methods
      save
        importing
                  iv_tablename type string
                  iv_objectid  type  if_chdo_object_tools_rel=>ty_cdobjectv optional
                  it_creates   type standard table optional
                  it_updates   type standard table optional
                  it_deletes   type standard table optional
        returning value(self)  type ref to zcl_interco_log.

  protected section.
  private section.
endclass.



class zcl_interco_log implementation.

  method save.

    field-symbols <creates> type standard table.
    field-symbols <updates> type standard table.
    field-symbols <deletes> type standard table.

    field-symbols <news> type standard table.
    field-symbols <olds> type standard table.

    data change_indicator type if_chdo_object_tools_rel=>ty_cdchngindh.

    data creates type ref to data.
    data updates type ref to data.
    data deletes type ref to data.
    data news type ref to data.
    data empty_line type ref to data.

    create data creates type table of (iv_tablename).
    create data updates type table of (iv_tablename).
    create data deletes type table of (iv_tablename).
    create data news type table of (iv_tablename).
    create data empty_line type (iv_tablename).

    assign news->* to <news>.
    assign creates->* to <creates>.
    assign updates->* to <updates>.
    assign deletes->* to <deletes>.

    <creates> = corresponding #( it_creates mapping from entity ).
    append lines of <creates> to <news>.
    <updates> = corresponding #( it_updates mapping from entity ).
    append lines of <updates> to <news>.
    <deletes> = corresponding #( it_deletes mapping from entity ).

    data(field_catalog) = cast cl_abap_structdescr( cl_abap_structdescr=>describe_by_data_ref( empty_line ) ).
    data(all_fields) = zcl_abap_structdescr=>new( field_catalog )->get_ddic_field_list( ).

    " Concatenate all Columns separated by comma (,). This is required because of an ATC check
    "that blocks 'select *'.
    data(sql_columns) = reduce string(
            init result = ``
            for key_field in all_fields
                next result = result &&
                              cond #( when strlen( result ) is initial then `` else `, ` ) &&
                              key_field-fieldname ).

    data(key_fields) =  all_fields.
    delete key_fields where datatype = 'CLNT' or keyflag <> abap_true.

    data(sql_where) = reduce string(
            init result = ``
            for key_field in key_fields
                next result = result &&
                              cond #( when strlen( result ) is initial then `` else ` AND ` ) &&
                              |{ key_field-fieldname } = @<NEWS>-{ key_field-fieldname }| ).

    data olds type ref to data.
    create data olds type table of (iv_tablename).

    assign olds->* to <olds>.

    if <news> is not initial.
      select (sql_columns) from (iv_tablename)
          for all entries in @<news>
          where (sql_where)
          into table @<olds>.
    endif.

    data(abap_where) = reduce string(
            init result = ``
            for key_field in key_fields
                next result = result &&
                              cond #( when strlen( result ) is initial then `` else ` AND ` ) &&
                              |{ key_field-fieldname } = <NEW>-{ key_field-fieldname }| ).

    do lines( <news> ) times.
      assign <news>[ sy-index ] to field-symbol(<new>).

      <new>-('client') = cond #( when <new>-('client') is initial then sy-mandt else <new>-('client') ).


      loop at <olds> assigning field-symbol(<old>)
        where (abap_where).
        exit.
      endloop.
      if sy-subrc is not initial.
        " in case it fails we have to make sure that `<old>`  is assigned to an empty structure.
        assign empty_line->* to <old>.
      endif.

      loop at <creates> transporting no fields
        where (abap_where).
        exit.
      endloop.
      if sy-subrc = 0.
        change_indicator = 'I'.
      endif.

      loop at <updates> transporting no fields
        where (abap_where).
        exit.
      endloop.
      if sy-subrc = 0.
        change_indicator = 'U'.
      endif.

      loop at <deletes> transporting no fields
          where (abap_where).
        exit.
      endloop.
      if sy-subrc = 0.
        change_indicator = 'D'.
      endif.

      final(current_time) = cl_abap_context_info=>get_system_time( ).
      final(current_date) = cl_abap_context_info=>get_system_date( ).
      final(current_user) = conv syuname( sy-uname ).
      final(objectid) = cond #( when iv_objectid is supplied then iv_objectid else iv_tablename ).

      data(chdo_class_name) = |ZCL_{ objectid }_CHDO|.
      data(write_parameters) = value abap_parmbind_tab(
                                    ( name  = 'OBJECTID'
                                      kind  = cl_abap_objectdescr=>exporting
                                      value = ref #( objectid ) )
                                    ( name  = 'UTIME'
                                      kind  = cl_abap_objectdescr=>exporting
                                      value = ref #( current_time ) )
                                    ( name  = 'UDATE'
                                      kind  = cl_abap_objectdescr=>exporting
                                      value = ref #( current_date ) )
                                    ( name  = 'USERNAME'
                                      kind  = cl_abap_objectdescr=>exporting
                                      value = ref #( current_user ) )
                                    ( name  = |O_{ objectid }|
                                      kind  = cl_abap_objectdescr=>exporting
                                      value = ref #( <old> ) )
                                    ( name  = |N_{ objectid }|
                                      kind  = cl_abap_objectdescr=>exporting
                                      value = ref #( <new> ) )
                                    ( name  = |UPD_{ objectid }|
                                      kind  = cl_abap_objectdescr=>exporting
                                      value = ref #( change_indicator ) )

      ).

      try.
          call method (chdo_class_name)=>write
            parameter-table write_parameters.
        catch cx_chdo_write_error.
          "  too late to do something.
      endtry.

    enddo.

    return me.

  endmethod.

endclass.
