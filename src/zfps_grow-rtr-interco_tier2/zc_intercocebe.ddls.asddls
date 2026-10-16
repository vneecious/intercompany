@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany CeBe''s equivalentes'
@Metadata.ignorePropagatedAnnotations: true
@UI.headerInfo: {
  typeName: 'Nodo',
  typeNamePlural: 'Nodos',
  title: {
    type: #STANDARD,
    value: 'ver_id'
  },
  description: {
    value: 'ProfitCenter'
  }
}
define root view entity ZC_INTERCOCEBE
  provider contract transactional_query
  as projection on ZI_INTERCOCEBE //( p_ver_id : '42010A5501221FD084FCAD100C75583C' )
{
      @UI: { lineItem: [ { position: 10, importance: #HIGH } ],
             identification: [ { position: 10 } ],
             selectionField: [{ element: 'ver_id', position: 10 }] }
      @EndUserText.label: 'Version ID'
  key ver_id,
      @UI: { lineItem: [ { position: 20, importance: #HIGH } ],
             identification: [ { position: 20 } ] }
      @EndUserText.label: 'Version ID'
  key node_id,
      @UI: { lineItem: [ { position: 30 } ],
             identification: [ { position: 30 } ],
             selectionField: [{ element: 'ProfitCenter', position: 20 }] }
      @EndUserText.label: 'ProfitCenter'
      ProfitCenter,
      @UI.lineItem: [ { position: 40 } ]
      @EndUserText.label: 'IsChild'
      IsChild,
//      @UI.lineItem: [ { position: 40 } ]
//      @EndUserText.label: 'Parent Nodo ID'
//      node_pid,
      @UI: { lineItem: [ { position: 50 } ],
             selectionField: [{ element: 'ParentProfitCenter', position: 30 }] }
      @EndUserText.label: 'ParentProfitCenter'
      ParentProfitCenter
}
