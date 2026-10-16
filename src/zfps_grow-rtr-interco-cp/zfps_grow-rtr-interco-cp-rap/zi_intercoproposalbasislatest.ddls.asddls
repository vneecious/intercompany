@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Latest ID from Proposal Basis'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}

define view entity ZI_IntercoProposalBasisLatest
  as select from zfi_a_intrc_cpib as _bLatest
  association of one to one zfi_a_intrc_cpic as _cLatest on  _cLatest.id      = _bLatest.id
                                                         and _cLatest.item_id = _bLatest.item_id
  association of one to one zfi_a_intrc_cpib as _b       on  _b.id           = $projection.Id
                                                         and _b.item_id      = $projection.Item_Id
                                                         and _b.itembasis_id = $projection.Itembasis_Id
  association of one to one zfi_a_intrc_cpic as _c       on  _c.id           = $projection.Id
                                                         and _c.item_id      = $projection.Item_Id
                                                         and _c.itembasis_id = $projection.Itembasis_Id
                                                         and _c.itemcalc_id  = $projection.Itemcalc_Id
{
  key _bLatest.id                as Id,
  key _bLatest.item_id           as Item_Id,
      max(_bLatest.itembasis_id) as Itembasis_Id,
      max(_cLatest.itemcalc_id)  as Itemcalc_Id,
      _b,
      _c
}
group by
  id,
  item_id
