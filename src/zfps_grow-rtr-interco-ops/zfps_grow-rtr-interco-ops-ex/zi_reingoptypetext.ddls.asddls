@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Tipo de Operacion - Textos'
@ObjectModel.dataCategory: #TEXT
@ObjectModel.representativeKey: 'OpType'
@ObjectModel.usageType.serviceQuality: #A
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #CUSTOMIZING

// ----------------------------------------------------------------------
// Autor  : EXT_AGFAGINA
// Fecha  : 25.09.2026
// Motivo : Ajustes Sprint 3 - Carga Mensual de Montos debe mostrar la
//          descripcion del tipo de operacion junto al codigo.
//          ZREING_OP_TYPE_T es la tabla de textos del catalogo de tipos de
//          operacion (mantenida por SM34, cluster ZREING_OP_TYPES) y tiene los
//          textos en ES / EN / PT. No habia ninguna vista CDS sobre ella.
//          Se usa desde ZI_ReingCMHeader con el idioma de sesion en el ON, asi
//          la asociacion queda [0..1] y el texto sale en el idioma del usuario.
// ----------------------------------------------------------------------
define view entity ZI_ReingOpTypeText
  as select from zreing_op_type_t
{
      @ObjectModel.text.element: ['OpTypeDesc']
  key op_type      as OpType,
      @Semantics.language: true
  key spras        as Language,
      @Semantics.text: true
      @EndUserText.label: 'Desc. Tipo Operacion'
      op_type_desc as OpTypeDesc
}
