@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CM - Registro de Carga Mensual'
@Metadata.allowExtensions: true

@UI.headerInfo: {
  typeName:       'Registro CM',
  typeNamePlural: 'Registros de Carga Mensual',
  title:       { type: #STANDARD, value: 'CtExtNum' },
  description: { type: #STANDARD, value: 'Matnr' }
}

define view entity ZC_ReingCMHeader
  as projection on ZI_ReingCMHeader
{
  key     CmHId,
          PeriodYear,
          PeriodMonth,

          @UI.hidden: true
          CtUuid,


          // Mod 30.09.2026 EXT_AGFAGINA - DF-554: se muestra "IC-0008 (GITHUB ENTERPRSE)".
          @ObjectModel.text.element: ['CtExtContract']
          @UI.textArrangement: #TEXT_LAST
          @EndUserText.label: 'Nro. Contrato'
          @UI.lineItem: [{ position: 10, importance: #HIGH }]
          @UI.selectionField: [{ position: 20 }]
          @UI.fieldGroup: [{ position: 10, qualifier: 'HeaderInfo' }]
          // Mod 12.09.2026 EXT_AGFAGINA: el value help ahora devuelve TAMBIEN el
          // CtUuid (usage: #RESULT). Sin eso, al elegir un contrato solo se
          // completaba el numero visible y CtUuid quedaba vacio: es el campo que
          // dispara DeriveContractData y el que la validacion exige, asi que la
          // linea nunca llegaba a guardarse.
          // ZI_ReingCMContractVH ya declara @ObjectModel.representativeKey: 'CtUuid',
          // o sea que estaba previsto devolverlo; solo faltaba declarar el binding.
          @Consumption.valueHelpDefinition: [{
            entity: { name: 'ZI_ReingCMContractVH', element: 'CtId' },
            additionalBinding: [{ localElement: 'CtUuid', element: 'CtUuid', usage: #RESULT }]
          }]
          CtExtNum,

          @UI.hidden: true
          MatUuid,

          @UI.hidden: true
          Lifnr,

          @UI.lineItem: [{ position: 30, label: 'Nombre Proveedor' }]
          @EndUserText.label: 'Nombre Proveedor'
          // Mod 12.09.2026 EXT_AGFAGINA: se navega por _Contract._Supplier en vez
          // de por la asociacion _Supplier de esta vista.
          // La de esta vista resuelve con "on $projection.Lifnr = _Supplier.Supplier",
          // y Lifnr NO es un campo de la tabla: es a su vez un derivado de _Contract.
          // O sea que el proveedor colgaba de DOS asociaciones encadenadas y en la
          // fila en edicion no se resolvia: el usuario elegia el contrato y el
          // Nombre Proveedor quedaba vacio hasta guardar.
          // ZI_ReingCTContract2 tiene lifnr como campo real y su propia asociacion
          // a I_Supplier, asi que por ahi la cadena es una sola y se resuelve igual
          // que MatDesc, que si funcionaba.
          _Contract._Supplier.SupplierName as SupplierName,

          // Mod 30.09.2026 EXT_AGFAGINA - DF-554: N. Contrato Externo, desde el
          // contrato. Se usa como TEXTO de CtExtNum (que pese al nombre guarda el
          // codigo IC-00xx), asi la columna muestra "IC-0008 (GITHUB ENTERPRSE)".
          // Solo lectura; no se agrega a la tabla draft (va por asociacion).
          @EndUserText.label: 'N. Contrato Externo'
          _Contract.ExtContract as CtExtContract,



          @EndUserText.label: 'Código Material'
          @UI.lineItem: [{ position: 40, importance: #HIGH }]
          @UI.selectionField: [{ position: 30 }]
          @UI.fieldGroup: [{ position: 40, qualifier: 'HeaderInfo' }]
          // Mod 12.09.2026 EXT_AGFAGINA: se cambia el value help.
          // Antes: ZI_ReingCTMatVH, sobre el catalogo general (I_ProductVH con un
          // LIKE 'ICSRV%'). Dos problemas: no devuelve MAT_UUID —el campo que el
          // BDEF exige y que dispara DeriveContractData— y ofrece TODOS los ICSRV
          // del sistema, no solo los del contrato, con lo cual el usuario podia
          // elegir materiales que BR-CM-03 iba a rechazar despues.
          // Ahora: ZI_ReingCMMaterialVH, que ya existia y resuelve las dos cosas.
          // Se filtra por el contrato de la fila (#FILTER) y devuelve el UUID
          // del material (#RESULT).
          @Consumption.valueHelpDefinition: [{
            entity: { name: 'ZI_ReingCMMaterialVH', element: 'Matnr' },
            additionalBinding: [ { localElement: 'CtUuid',  element: 'CtUuid',  usage: #FILTER },
                                 { localElement: 'MatUuid', element: 'MatUuid', usage: #RESULT } ]
          }]
          Matnr,

          @UI.lineItem: [{ position: 50, label: 'Desc. Material' }]
          @EndUserText.label: 'Descripción Material'
          _Material.MatDesc      as MatDesc,



          @EndUserText.label: 'Tipo de operación'
          @UI.lineItem: [{ position: 60, importance: #HIGH }]
          @UI.selectionField: [{ position: 40 }]
          @UI.fieldGroup: [{ position: 60, qualifier: 'HeaderInfo' }]
          @Consumption.valueHelpDefinition: [{
            entity: { name: 'ZI_ReingCMOpTypeVH', element: 'OpType' },
            additionalBinding: [ { localElement: 'CtUuid',  element: 'CtUuid',  usage: #FILTER },
                                 { localElement: 'MatUuid', element: 'MatUuid', usage: #FILTER } ]
          }]
          OpType,

          // Mod 25.09.2026 EXT_AGFAGINA - Ajustes Sprint 3: descripcion del tipo de
          // operacion, desde ZREING_OP_TYPE_T en el idioma de sesion. Solo lectura.
          @UI.lineItem: [{ position: 61, label: 'Desc. Tipo Operación' }]
          @UI.fieldGroup: [{ position: 61, qualifier: 'HeaderInfo', label: 'Desc. Tipo Operación' }]
          @EndUserText.label: 'Desc. Tipo Operación'
          _OpTypeText.OpTypeDesc as OpTypeDesc,

          // Mod 01.10.2026 EXT_AGFAGINA - defecto 109: numero de activacion (instancia
          // de la operacion del contrato). Se completa solo cuando el contrato tiene
          // una unica opcion del tipo; con varias, lo indica el usuario.
          @UI.lineItem: [{ position: 62, label: 'Nro. Activación' }]
          @UI.fieldGroup: [{ position: 62, qualifier: 'HeaderInfo', label: 'Nro. Activación' }]
          @EndUserText.label: 'Nro. Activación'
          OpInstanceNum,


          @UI.lineItem: [{ position: 70, label: 'Padron/Bonif.' }]
          @UI.fieldGroup: [{ qualifier: 'CM_DATA', position: 70, label: 'Padron / Bonificacion' }]
          DeferType,

          // Begin Mod 08.09.2026 EXT_AGFAGINA - distribucion del devengamiento.
          // Es lo que el funcional esperaba ver en "Tipo Dev.": si el devengamiento
          // configurado en el contrato es Lineal o Espacial.
          // Se expone como campo propio y NO se reutiliza DeferType, porque ese
          // guarda Padron/Bonificacion y de el dependen BR-CM-12, BR-CM-13 y la
          // validacion que exige P o B en toda Activacion.
          // Derivado del contrato: solo lectura, no participa de validaciones.
          // Se renombra ademas la etiqueta de DeferType a "Padron/Bonif." para que
          // deje de confundirse con el tipo de operacion D - Devengamiento de CT.
          @UI.lineItem: [{ position: 75, label: 'Distribucion' }]
          @UI.fieldGroup: [{ qualifier: 'CM_DATA', position: 75, label: 'Distribucion Devengamiento' }]
          _OpTypeDist.DistType as DistType,
          // End Mod 08.09.2026 EXT_AGFAGINA

          @UI.hidden: true
          LoadSeq,

          @UI.lineItem: [{ position: 80, label: 'Delta' }]
          @UI.fieldGroup: [{ qualifier: 'CM_DATA', position: 80, label: 'Delta' }]
          DeltaFlag,

          @UI.lineItem: [{ position: 85, label: 'T-2' }]
          @Semantics.amount.currencyCode: 'Currency'
          @EndUserText.label: 'Monto T-2'
          @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_REING_CM_VE_PREV'
  virtual AmountPrev2 : abap.curr( 15, 2 ),


          @UI.lineItem: [{ position: 87, label: 'T-1' }]
          @Semantics.amount.currencyCode: 'Currency'
          @EndUserText.label: 'Monto T-1'
          @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_REING_CM_VE_PREV'
  virtual AmountPrev1 : abap.curr( 15, 2 ),

          @UI.lineItem: [{ position: 90, label: 'Monto', importance: #HIGH }]
          @UI.fieldGroup: [{ qualifier: 'CM_DATA', position: 90, label: 'Monto' }]
          Amount,

          @UI.lineItem: [{ position: 100, label: 'Moneda' }]
          @UI.fieldGroup: [{ qualifier: 'CM_DATA', position: 100, label: 'Moneda' }]
          @Consumption.valueHelpDefinition: [{
            entity: { name: 'ZI_ReingCMCurrencyVH', element: 'Currency' },
            additionalBinding: [{ localElement: 'CtUuid', element: 'CtUuid', usage: #FILTER }]
          }]
          Currency,

          @UI.hidden: true
          CtWaers,

          @EndUserText.label: 'Estado'
          @ObjectModel.text.element: ['CmStatusText']
          @UI.lineItem: [{
            position: 110,
            label: 'Estado',
            criticality: 'StatusCriticality',
            criticalityRepresentation: #WITHOUT_ICON
          }]
          CmStatus,

          @EndUserText.label: 'Estado (Texto)'
          @UI.hidden: true
          @Semantics.text: true
          CmStatusText,

          @UI.hidden: true
          StatusCriticality,

          @UI.lineItem: [{ type: #FOR_ACTION, dataAction: 'Enviar',
                           label: 'Enviar a Liberación', position: 120 }]
          CmStatus               as CmStatusEnviar,

          @UI.lineItem: [{ type: #FOR_ACTION, dataAction: 'Liberar',
                           label: 'Liberar', position: 130 }]
          CmStatus               as CmStatusLiberar,

          @UI.lineItem: [{ type: #FOR_ACTION, dataAction: 'Devolver',
                           label: 'Devolver', position: 140 }]
          CmStatus               as CmStatusDevolver,

          @UI.hidden: true
          LoadUser,
          @UI.hidden: true
          LoadDate,
          @UI.hidden: true
          SentBy,
          @UI.hidden: true
          SentAt,
          @UI.hidden: true
          ReleasedBy,
          @UI.hidden: true
          ReleasedAt,
          @UI.hidden: true
          AccountingDoc,
          @UI.hidden: true
          CreatedBy,
          @UI.hidden: true
          CreatedAt,
          @UI.hidden: true
          ChangedBy,
          @UI.hidden: true
          ChangedAt,

          _Period : redirected to parent ZC_ReingCMPeriod,
          _Contract,
          _Material,
          _Supplier,
          _Receivers : redirected to composition child ZC_ReingCMRecv,
          // Mod 02.10.2026 EXT_AGFAGINA - defecto 518: historial de cambios.
          _Log
}
