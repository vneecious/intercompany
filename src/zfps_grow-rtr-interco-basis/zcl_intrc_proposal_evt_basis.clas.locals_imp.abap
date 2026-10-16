*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations
CLASS lcl_event_consumption DEFINITION INHERITING FROM cl_abap_behavior_event_handler.
  PRIVATE SECTION.
    METHODS proposal_deleted FOR ENTITY EVENT keys FOR zi_intercoproposal~deleted.

ENDCLASS.


CLASS lcl_event_consumption IMPLEMENTATION.

  METHOD proposal_deleted.

    DATA proposals_range TYPE RANGE OF zi_intercoproposal-id.

    proposals_range = VALUE #( FOR key IN keys ( sign = 'I' option = 'EQ' low = key-id ) ).
    SELECT basis~id, COUNT( proposals~id ) AS count_proposals FROM zi_intercoproposal AS proposal
        INNER JOIN zi_intercobasis AS basis ON basis~id = proposal~intercobasisid
        LEFT OUTER JOIN zi_intercoproposal AS proposals ON proposals~intercobasisid = basis~id
        AND ( proposals~isdeleted = @abap_false
        AND proposals~status <> @zcl_proposal_bo_abs=>c_document_status-anulated )
        WHERE proposal~id IN @proposals_range
              GROUP BY basis~id
              INTO TABLE @DATA(bases).

    MODIFY ENTITIES OF zi_intercobasis
        ENTITY zi_intercobasis EXECUTE unreleasebasis
        FROM VALUE #( FOR basis IN bases WHERE ( count_proposals = 0 )
                                               ( id              = basis-id )
    ).

  ENDMETHOD.
ENDCLASS.
