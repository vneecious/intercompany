@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CM - Historial de acciones'
@Metadata.allowExtensions: true
// Mod 02.10.2026 EXT_AGFAGINA - defecto 518: historial de cambios (ET 7.9). Se
// muestra como seccion al final del detalle del registro, del mas reciente al mas
// viejo. Ademas de las acciones (Enviar/Liberar/Devolver) registra altas, bajas,
// cambios campo por campo y sustituciones (SUPS).
//
// Mod 06.10.2026 EXT_AGFAGINA - defecto 518, historial del PERIODO: el front pasa
// el dialogo Historial de una sap.m.Table manual a sap.fe.macros.Table (relevamiento
// de front del 06.10.2026). Se agregan anotaciones con qualifier PeriodHistory, de
// modo que conviven dos presentaciones sobre la misma entidad:
//   - sin qualifier: seccion "Historial de cambios" del detalle (6 columnas);
//   - #PeriodHistory: dialogo del periodo (14 columnas, mismo recorrido que el
//     dialogo actual mas campo / valor anterior / valor nuevo).
// El orden del periodo desempata por LogId: es un UUID, asi que no es cronologico,
// pero estabiliza la paginacion cuando dos eventos tienen el mismo ActionAt.
@UI.headerInfo: { typeName: 'Cambio', typeNamePlural: 'Historial de cambios' }
@UI.presentationVariant: [
  { sortOrder: [{ by: 'ActionAt', direction: #DESC }] },
  { qualifier: 'PeriodHistory',
    sortOrder: [{ by: 'ActionAt', direction: #DESC },
                { by: 'LogId',    direction: #DESC }],
    visualizations: [{ type: #AS_LINEITEM, qualifier: 'PeriodHistory' }] }
]
define view entity ZC_ReingCMLog
  as select from zreing_cm_log as Log
{
  key Log.log_id        as LogId,
      Log.cm_h_id       as CmHId,
      Log.period_year   as PeriodYear,
      Log.period_month  as PeriodMonth,
      @UI.lineItem: [{ position: 30, label: 'Acción' },
                     { qualifier: 'PeriodHistory', position: 80, label: 'Acción' }]
      @EndUserText.label: 'Acción'
      Log.action_code   as ActionCode,
      @UI.lineItem: [{ qualifier: 'PeriodHistory', position: 10, label: 'Contrato' }]
      @EndUserText.label: 'Contrato'
      Log.ct_ext_num    as CtExtNum,
      @UI.lineItem: [{ qualifier: 'PeriodHistory', position: 20, label: 'Material' }]
      @EndUserText.label: 'Material'
      Log.matnr         as Matnr,
      @UI.lineItem: [{ qualifier: 'PeriodHistory', position: 30, label: 'Tipo de operación' }]
      @EndUserText.label: 'Tipo de operación'
      Log.op_type       as OpType,
      // El titulo "Tipo Dev." se confundia con la distribucion del devengamiento.
      @UI.lineItem: [{ qualifier: 'PeriodHistory', position: 40, label: 'Padrón/Bonificación' }]
      @EndUserText.label: 'Padrón/Bonificación'
      Log.defer_type    as DeferType,
      @UI.lineItem: [{ qualifier: 'PeriodHistory', position: 50, label: 'Secuencia' }]
      @EndUserText.label: 'Secuencia'
      Log.load_seq      as LoadSeq,
      @UI.lineItem: [{ qualifier: 'PeriodHistory', position: 60, label: 'Monto' }]
      @EndUserText.label: 'Monto'
      @Semantics.amount.currencyCode: 'Currency'
      Log.amount        as Amount,
      @UI.lineItem: [{ qualifier: 'PeriodHistory', position: 70, label: 'Moneda' }]
      @EndUserText.label: 'Moneda'
      Log.currency      as Currency,
      @UI.lineItem: [{ qualifier: 'PeriodHistory', position: 120, label: 'Estado',
                       criticality: 'StatusCriticality',
                       criticalityRepresentation: #WITH_ICON }]
      @EndUserText.label: 'Estado'
      Log.cm_status     as CmStatus,
      // Criticidad del estado GUARDADO en la fila del log (foto del evento), no la
      // del registro actual: el registro puede haber cambiado de estado o no existir.
      // Reproduce el dialogo actual: LIBD verde, ENVI advertencia, resto neutral
      // (incluido ERR). Campo tecnico: no se muestra como columna.
      @UI.hidden: true
      case Log.cm_status
        when 'LIBD' then 3
        when 'ENVI' then 2
        else 0
      end               as StatusCriticality,
      @UI.lineItem: [{ position: 20, label: 'Usuario' },
                     { qualifier: 'PeriodHistory', position: 130, label: 'Realizado por' }]
      @EndUserText.label: 'Usuario'
      Log.action_user   as ActionUser,
      @UI.lineItem: [{ position: 10, label: 'Fecha y hora' },
                     { qualifier: 'PeriodHistory', position: 140, label: 'Fecha y hora' }]
      @EndUserText.label: 'Fecha y hora'
      Log.action_at     as ActionAt,
      @UI.lineItem: [{ position: 40, label: 'Campo' },
                     { qualifier: 'PeriodHistory', position: 90, label: 'Campo' }]
      @EndUserText.label: 'Campo'
      Log.field_name    as FieldName,
      @UI.lineItem: [{ position: 50, label: 'Valor anterior' },
                     { qualifier: 'PeriodHistory', position: 100, label: 'Valor anterior' }]
      @EndUserText.label: 'Valor anterior'
      Log.value_old     as ValueOld,
      @UI.lineItem: [{ position: 60, label: 'Valor nuevo' },
                     { qualifier: 'PeriodHistory', position: 110, label: 'Valor nuevo' }]
      @EndUserText.label: 'Valor nuevo'
      Log.value_new     as ValueNew
}
