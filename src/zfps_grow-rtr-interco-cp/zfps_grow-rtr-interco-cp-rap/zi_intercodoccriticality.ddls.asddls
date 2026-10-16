@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Criticidad de docs por item'
define view entity ZI_IntercoDocCriticality
  as select from ZI_IntercoDocStatus_Helper
  association to ZI_IntercoProposalItemDoc as _ProposalItemDoc on  $projection.id      = _ProposalItemDoc.id
                                                               and $projection.item_id = _ProposalItemDoc.item_id
{
  key id,
  key item_id,

      // El valor más bajo de StatusPriority indica el estado de mayor prioridad
      min(StatusPriority) as StatusCriticality
}
group by
  id,
  item_id
