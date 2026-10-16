CLASS zcl_fi_intrc_md_exemptions_ve DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_sadl_exit_calc_element_read.

    CONSTANTS:
      BEGIN OF c_entity_properties,
        validity_text TYPE string VALUE 'VALIDITYTEXT',
      END OF c_entity_properties.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_fi_intrc_md_exemptions_ve IMPLEMENTATION.
  METHOD if_sadl_exit_calc_element_read~calculate.

    DATA original_data TYPE zc_intercoexemptiontp.
    LOOP AT it_original_data ASSIGNING FIELD-SYMBOL(<original_data>).
      original_data = CORRESPONDING #( <original_data> ).

      IF line_exists( it_requested_calc_elements[ table_line = c_entity_properties-validity_text ] ).
        ASSIGN COMPONENT c_entity_properties-validity_text OF STRUCTURE ct_calculated_data[ sy-tabix ] TO FIELD-SYMBOL(<new_validity>).
        <new_validity> = |{ original_data-validfrom DATE = USER } - { original_data-validto DATE = USER }|.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD if_sadl_exit_calc_element_read~get_calculation_info.

  ENDMETHOD.

ENDCLASS.
