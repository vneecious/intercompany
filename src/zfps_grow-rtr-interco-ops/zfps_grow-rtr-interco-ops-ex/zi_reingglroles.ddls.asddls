@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CT - Value Help Roles Contables'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@Search.searchable: true

// Begin Mod V001 (CC) — FX16 — convert classic view to view entity for proper OData V4 EntityType
// Autor  : AGF
// Fecha  : 18.06.2026
// Delta v1.6 - Agregar RoleCategory. RoleType marcado obsoleto (se mantiene en modelo)

define view entity ZI_ReingGLRoles
  as select from zreing_gl_roles
{
  @Search.defaultSearchElement: true
  @Search.ranking: #HIGH
  key gl_role          as GlRole,
  @Search.defaultSearchElement: true
  @Search.ranking: #MEDIUM
      descr            as Descr,
      role_category    as RoleCategory,
      // RoleType: OBSOLETO (Delta v1.6) - se mantiene por compatibilidad
      role_type        as RoleType,
      tax_type         as TaxType,
      auto_determ      as AutoDeterm,
      reclassify       as Reclassify,
      posting_context  as PostingContext,
      role_reclas      as RoleReclas
}
// End Mod V001 (CC) — FX16
