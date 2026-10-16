@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Resume Proposal by status'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZC_proposalbystatus as projection on ZR_PROPOSALBYSTATUS
{
    key Status,
    StatusName,
    StatusCriticaly,
    quan
}
