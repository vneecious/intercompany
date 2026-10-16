class zcl_abap_structdescr definition
  public
  final
  create private .

  public section.

    types ty_FIELD_LIST type dfies.
    types tt_field_list type table of ty_field_list with key tabname fieldname langu.

    class-methods new
      importing
                wrapped_instance type ref to cl_abap_structdescr
      returning value(result)    type ref to zcl_abap_structdescr.

    methods get_ddic_field_list
      importing
        value(p_langu)            type langu default sy-langu
        !p_including_substructres type abap_bool default abap_false
      returning
        value(p_field_list)       type tt_field_list.
  protected section.
  private section.
    class-data m_instance type ref to zcl_abap_structdescr.
    data m_wrapped_instance type ref to cl_abap_structdescr.
endclass.


class zcl_abap_structdescr implementation.
  method new.
    if m_instance is not bound.
      m_instance =  new #( ).
    endif.

    m_instance->m_wrapped_instance = wrapped_instance.
    return m_instance.
  endmethod.

  method get_ddic_field_list.
    try.
        return corresponding #( m_wrapped_instance->get_ddic_field_list(
          exporting
            p_langu                  = p_langu
            p_including_substructres = p_including_substructres
        ) ).
      catch cx_root.
    endtry.
  endmethod.
endclass.
