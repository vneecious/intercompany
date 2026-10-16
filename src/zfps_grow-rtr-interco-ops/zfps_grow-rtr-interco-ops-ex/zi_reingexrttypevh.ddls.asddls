@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'VH Tipo de Tasa de Cambio IC'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #CUSTOMIZING
@Search.searchable: true

// Autor  : EXT_OSCUGALD
// Fecha  : 03.06.2026
// Cambio : Se marca ExchRateTypeDesc como texto para @ObjectModel.text.association

define view entity ZI_ReingExrtTypeVH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZREING_EXRT_TYPE' )
{
      @Search.defaultSearchElement: true
  key value_low as ExchRateType,
      // Marca el campo como texto para que Fiori Elements lo muestre en lugar del ID
      @Semantics.text: true
      text      as ExchRateTypeDesc
}
// Begin Mod (31.08.2026 | EXT_AGFAGINA) — filtro por idioma de sesion.
// Sin este WHERE la vista devuelve UNA FILA POR IDIOMA TRADUCIDO (H/Inherited +
// H/Heredado, M/Manual + M/Manual, P/Monthly Avg. + P/Promedio Mes): la clave
// declarada (value_low) queda duplicada y el value help colapsaba a un unico
// valor, el primero en ingles. En la app solo se ofrecia "H - Inherited" y no se
// podia elegir "P - Promedio Mes".
// Los demas VH de dominio del proyecto no lo manifiestan solo porque sus dominios
// estan traducidos a un unico idioma; el defecto es del patron, no de este campo.
where language = $session.system_language
// End Mod (31.08.2026 | EXT_AGFAGINA)
