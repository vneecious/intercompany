*"* use this source file for any type of declarations (class
*"* definitions, interfaces or type declarations) you need for
*"* components in the private section

" V001 (CC) - VAL-TX-01 (Brazil): isolated handler tests.
CLASS lcl_tx_fixture DEFINITION FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    CLASS-DATA mt_rules TYPE TABLE FOR READ RESULT zi_reingtxrule.
    CLASS-DATA mt_created TYPE TABLE FOR CREATE zi_reingtxrule.
    CLASS-DATA mv_scope_reads TYPE i.
    CLASS-DATA mv_overlap_reads TYPE i.
    CLASS-DATA mv_creates TYPE i.
ENDCLASS.
