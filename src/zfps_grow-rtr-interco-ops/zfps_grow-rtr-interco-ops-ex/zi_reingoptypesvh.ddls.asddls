@AbapCatalog.sqlViewName: 'ZV_REINGOPTYP2'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CT - VH Tipos Operacion sin D y NC'
@Search.searchable: true

// Autor  : AGF
// Fecha  : 03.06.2026
// T8 - Excluye DEVENGAMIENTO (D) y NOTA DE CREDITO (NC) del matchcode

define view ZI_ReingOpTypesVH
  as select from zreing_op_types
{
      @Search.defaultSearchElement: true
      @Search.ranking: #HIGH
  key op_type as OpType,
      // Autor  : EXT_OSCUGALD
      // Fecha  : 03.06.2026
      // Cambio : Se marca como texto para que @ObjectModel.text.association lo consuma
      @Semantics.text: true
      @Search.defaultSearchElement: true
      @Search.ranking: #MEDIUM
      descr   as Descr
}
where
      op_type <> 'D'
  and op_type <> 'NC'
