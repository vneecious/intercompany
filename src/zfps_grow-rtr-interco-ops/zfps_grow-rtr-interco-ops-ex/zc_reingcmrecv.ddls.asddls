@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'CM - Receptoras (Proyeccion)'
@Metadata.allowExtensions: true

@UI.headerInfo: {
  typeName:       'Receptora',
  typeNamePlural: 'Receptoras Participantes'
}

define view entity ZC_ReingCMRecv
  as projection on ZI_ReingCMRecv
{
  key CmHId,

      @EndUserText.label: 'Sociedad Receptora'
      @UI.lineItem: [{ position: 10, importance: #HIGH }]
      @Consumption.valueHelpDefinition: [{
        entity: { name: 'ZI_ReingCTReceiver2', element: 'RecBukrs' },
        additionalBinding: [
          { localElement: 'CtUuid',  element: 'CtUuid',  usage: #FILTER },
          { localElement: 'MatUuid', element: 'MatUuid', usage: #FILTER }
        ] }]
  key BukrsRecv,

      @UI.hidden: true
      PeriodYear,
      @UI.hidden: true
      PeriodMonth,
      @UI.hidden: true
      CtUuid,
      @UI.hidden: true
      MatUuid,

      @UI.hidden: true
      CreatedBy,
      @UI.hidden: true
      CreatedAt,
      @UI.hidden: true
      ChangedBy,
      @UI.hidden: true
      ChangedAt,

      _Header : redirected to parent ZC_ReingCMHeader,
      _Period : redirected to ZC_ReingCMPeriod
}
