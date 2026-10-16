class zcl_fi_intrc_messages definition
  public
  create private inheriting from cx_no_check.

  public section.

    interfaces if_abap_behv_message .

    aliases msgty
      for if_t100_dyn_msg~msgty .
    aliases msgv1
      for if_t100_dyn_msg~msgv1 .
    aliases msgv2
      for if_t100_dyn_msg~msgv2 .
    aliases msgv3
      for if_t100_dyn_msg~msgv3 .
    aliases msgv4
      for if_t100_dyn_msg~msgv4 .

    constants ms like if_abap_behv_message=>severity value if_abap_behv_message=>severity ##NO_TEXT.

    class-methods new_message
      importing
        !textid       like if_t100_message=>t100key
        !severity     type if_abap_behv_message=>t_severity
        !v1           type simple optional
        !v2           type simple optional
        !v3           type simple optional
        !v4           type simple optional
      returning
        value(result) type ref to if_abap_behv_message.

    constants:
      gc_msgid type symsgid value 'ZFI_INTERCO',

      begin of date_overlaps,
        msgid type symsgid value gc_msgid,
        msgno type symsgno value '201',
        attr1 type scx_attrname value 'LINE_NUMBER',
        attr2 type scx_attrname value '',
        attr3 type scx_attrname value '',
        attr4 type scx_attrname value '',
      end of date_overlaps,

      begin of date_interval,
        msgid type symsgid value gc_msgid,
        msgno type symsgno value '202',
        attr1 type scx_attrname value 'LINE_NUMBER',
        attr2 type scx_attrname value '',
        attr3 type scx_attrname value '',
        attr4 type scx_attrname value '',
      end of date_interval,

      begin of FIELD_required,
        msgid type symsgid value gc_msgid,
        msgno type symsgno value '203',
        attr1 type scx_attrname value 'LINE_NUMBER',
        attr2 type scx_attrname value '',
        attr3 type scx_attrname value '',
        attr4 type scx_attrname value '',
      end of FIELD_required,

      begin of at_least_one_required,
        msgid type symsgid value gc_msgid,
        msgno type symsgno value '204',
        attr1 type scx_attrname value 'LINE_NUMBER',
        attr2 type scx_attrname value '',
        attr3 type scx_attrname value '',
        attr4 type scx_attrname value '',
      end of at_least_one_required,

      begin of relation_not_exists,
        msgid type symsgid value gc_msgid,
        msgno type symsgno value '205',
        attr1 type scx_attrname value 'LINE_NUMBER',
        attr2 type scx_attrname value 'PRODUCT',
        attr3 type scx_attrname value 'COMPANY_CODE',
        attr4 type scx_attrname value '',
      end of relation_not_exists,

      begin of duplicated_rule,
        msgid type symsgid value gc_msgid,
        msgno type symsgno value '206',
        attr1 type scx_attrname value 'LINE_NUMBER',
        attr2 type scx_attrname value '',
        attr3 type scx_attrname value '',
        attr4 type scx_attrname value '',
      end of duplicated_rule,

      begin of no_authority,
        msgid type symsgid value gc_msgid,
        msgno type symsgno value '207',
        attr1 type scx_attrname value '',
        attr2 type scx_attrname value '',
        attr3 type scx_attrname value '',
        attr4 type scx_attrname value '',
      end of no_authority,

      begin of invalid_field_value,
        msgid type symsgid value gc_msgid,
        msgno type symsgno value '208',
        attr1 type scx_attrname value 'LINE_NUMBER',
        attr2 type scx_attrname value 'FIELD_VALUE',
        attr3 type scx_attrname value 'FIELD_NAME',
        attr4 type scx_attrname value '',
      end of invalid_field_value,


      begin of basis_overwrite,
        msgid type symsgid value gc_msgid,
        msgno type symsgno value '209',
        attr1 type scx_attrname value 'BASIS_ID',
        attr2 type scx_attrname value 'CREATED_BY',
        attr3 type scx_attrname value '',
        attr4 type scx_attrname value '',
      end of basis_overwrite,

      begin of basis_no_billable,
        msgid type symsgid value gc_msgid,
        msgno type symsgno value '210',
        attr1 type scx_attrname value '',
        attr2 type scx_attrname value '',
        attr3 type scx_attrname value '',
        attr4 type scx_attrname value '',
      end of basis_no_billable,

      begin of profit_center_not_in_relations,
        msgid type symsgid value gc_msgid,
        msgno type symsgno value '211',
        attr1 type scx_attrname value 'PROFIT_CENTER',
        attr2 type scx_attrname value 'PROVIDER_COMPANY_CODE',
        attr3 type scx_attrname value '',
        attr4 type scx_attrname value '',
      end of profit_center_not_in_relations,

      begin of proposal_create_error,
        msgid type symsgid value gc_msgid,
        msgno type symsgno value '212',
        attr1 type scx_attrname value '',
        attr2 type scx_attrname value '',
        attr3 type scx_attrname value '',
        attr4 type scx_attrname value '',
      end of proposal_create_error.

  protected section.
  private section.
    methods constructor
      importing
        !textid   like if_t100_message=>t100key optional
        !previous like previous optional
        !msgty    type symsgty optional
        !msgv1    type simple optional
        !msgv2    type simple optional
        !msgv3    type simple optional
        !msgv4    type simple optional .
endclass.



class zcl_fi_intrc_messages implementation.

  method constructor ##ADT_SUPPRESS_GENERATION.
    call method super->constructor exporting previous = previous.
    me->msgty = msgty .
    me->msgv1 = msgv1 .
    me->msgv2 = msgv2 .
    me->msgv3 = msgv3 .
    me->msgv4 = msgv4 .
    clear me->textid.
    if textid is initial.
      if_t100_message~t100key = if_t100_message=>default_textid.
    else.
      if_t100_message~t100key = textid.
    endif.
  endmethod.

  method new_message .

    data(_textid) = textid.

    _textid-attr1 = cond #( when v1 is not initial then 'IF_T100_DYN_MSG~MSGV1' ).
    _textid-attr2 = cond #( when v2 is not initial then 'IF_T100_DYN_MSG~MSGV2' ).
    _textid-attr3 = cond #( when v3 is not initial then 'IF_T100_DYN_MSG~MSGV3' ).
    _textid-attr4 = cond #( when v4 is not initial then 'IF_T100_DYN_MSG~MSGV4' ).

    result = new zcl_fi_intrc_messages( textid = _textid
                                        msgty  = switch #( severity
                                                   when ms-error       then 'E'
                                                   when ms-warning     then 'W'
                                                   when ms-information then 'I'
                                                   when ms-success     then 'S' )
                                        msgv1  = |{ v1 }|
                                        msgv2  = |{ v2 }|
                                        msgv3  = |{ v3 }|
                                        msgv4  = |{ v4 }|
                                        ).

    result->m_severity = severity.

  endmethod.
endclass.
