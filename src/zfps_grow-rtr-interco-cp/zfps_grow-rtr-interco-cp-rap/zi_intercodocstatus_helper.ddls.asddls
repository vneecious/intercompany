@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Helper View for Document Status'
define view entity ZI_IntercoDocStatus_Helper
  as select from ZI_IntercoProposalItemDoc
{
  key id,
  key item_id,
      Status as DocumentStatus,
      // Asignar un valor numérico a cada estado para determinar la prioridad
      case Status
        when 'E' then 1 // Crítico (Rojo)
        when 'G' then 1 // Crítico (Rojo)
        when 'C' then 3 // Éxito (Verde)
        when 'F' then 3 // Éxito (Verde)
        when ''  then 1 // Crítico (Rojo)
        else 2          // Por defecto, advertencia
      end    as StatusPriority
}
