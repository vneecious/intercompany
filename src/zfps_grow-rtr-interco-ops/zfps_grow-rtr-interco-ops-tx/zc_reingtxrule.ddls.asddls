@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'TX - Reglas Fiscales (Projection)'
@Metadata.allowExtensions: true
@Search.searchable: true
@UI: {
  headerInfo: {
    typeName: 'Regla Fiscal',
    typeNamePlural: 'Reglas Fiscales',
    title: { type: #STANDARD, value: 'TxRuleId' },
    description: { type: #STANDARD, value: 'Description' }
  }
}
define root view entity ZC_ReingTXRule
  provider contract transactional_query
  as projection on ZI_ReingTXRule
{
      @UI: {
        facet: [ { id: 'idGeneral', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE,
                   label: 'Datos Generales', position: 10 } ],
        lineItem:       [{ position: 10, importance: #HIGH }],
        identification: [{ position: 10, label: 'Regla (ID)' },
                         { type: #FOR_ACTION, dataAction: 'ActivateRule', label: 'Activar',    position: 910 },
                         { type: #FOR_ACTION, dataAction: 'Deactivate',   label: 'Desactivar', position: 920 },
                         { type: #FOR_ACTION, dataAction: 'CopyRule',     label: 'Copiar',     position: 930 }]
      }
      @EndUserText.label: 'Regla (ID)'
      @Search.defaultSearchElement: true
  key TxRuleId,
      @UI: {
        lineItem:       [{ position: 20, importance: #HIGH }],
        selectionField: [{ position: 10 }],
        identification: [{ position: 20 }]
      }
      // Mod 25.09.2026 EXT_AGFAGINA - Ajustes Sprint 3: "Pais" -> "País Receptor".
      // El campo es el pais de la sociedad receptora; con la columna "Pais
      // Prestadora" al lado, la etiqueta generica "Pais" era ambigua.
      @EndUserText.label: 'País Receptor'
      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_Country', element: 'Country' } }]
      @Search.defaultSearchElement: true
      Country,
      // V009 (15.09.2026) - ET-REING-BR-001 v5 SS4.7.3/SS4.7.4. The spec asks
      // for positions 25/30/35, but 30 and 40 are already taken by Lifnr and
      // Matnr; 21/22/23 are free and keep the new fields next to Country,
      // which is where they belong semantically and needs no renumbering.
      // Annotations go inline because this projection has no Metadata
      // Extension despite @Metadata.allowExtensions -- every @UI here is
      // inline, so creating a DDLX would mean migrating all of them.
      @UI: {
        lineItem:       [{ position: 21, importance: #HIGH }],
        selectionField: [{ position: 11 }],
        identification: [{ position: 21 }]
      }
      @EndUserText.label: 'Pais Prestadora'
      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_Country', element: 'Country' } }]
      CountryPrest,
      @UI: {
        lineItem:       [{ position: 22, importance: #HIGH }],
        selectionField: [{ position: 12 }],
        identification: [{ position: 22 }]
      }
      @EndUserText.label: 'Soc. Prestadora'
      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_CompanyCode', element: 'CompanyCode' } }]
      BukrsPrest,
      @UI: {
        lineItem:       [{ position: 23, importance: #HIGH }],
        selectionField: [{ position: 13 }],
        identification: [{ position: 23 }]
      }
      @EndUserText.label: 'Soc. Receptora'
      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_CompanyCode', element: 'CompanyCode' } }]
      BukrsRecv,
      @UI: {
        lineItem:       [{ position: 50, importance: #HIGH }],
        selectionField: [{ position: 40 }],
        identification: [{ position: 30 }],
        textArrangement: #TEXT_LAST
      }
      @EndUserText.label: 'Tipo Impuesto'
      //@Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_ReingTXTypeDomVH', element: 'TaxType' } }]
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_ReingTXTypeVH', element: 'TaxType' } }]
      @Search.defaultSearchElement: true
      TaxType,
      @UI: {
        lineItem:       [{ position: 40, importance: #MEDIUM }],
        selectionField: [{ position: 30 }],
        identification: [{ position: 40 }]
      }
      @EndUserText.label: 'Material (MATNR)'
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_ReingCTMatVH', element: 'Product' } }]
      Matnr,
      // Mod 25.09.2026 EXT_AGFAGINA - Ajustes Sprint 3: descripcion del material.
      // Se trae por _Material (I_Product) -> _Text filtrado por idioma de sesion,
      // asi la columna muestra el texto en el idioma del usuario y la cardinalidad
      // queda en uno. Solo lectura: es derivado, no se persiste.
      @UI: {
        lineItem:       [{ position: 41, importance: #MEDIUM }],
        identification: [{ position: 41 }]
      }
      @EndUserText.label: 'Desc. Material'
      _Material._Text[1: Language = $session.system_language].ProductName as MaterialName,
      @UI: {
        lineItem:       [{ position: 30, importance: #MEDIUM }],
        selectionField: [{ position: 20 }],
        identification: [{ position: 50 }]
      }
      @EndUserText.label: 'Proveedor (LIFNR)'
      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_Supplier', element: 'Supplier' } }]
      Lifnr,
      // Mod 25.09.2026 EXT_AGFAGINA - Ajustes Sprint 3: nombre del proveedor.
      // Derivado de _Supplier (I_Supplier), solo lectura.
      @UI: {
        lineItem:       [{ position: 31, importance: #MEDIUM }],
        identification: [{ position: 51 }]
      }
      @EndUserText.label: 'Nombre Proveedor'
      _Supplier.SupplierName as SupplierName,
      @UI: {
        lineItem:       [{ position: 60, importance: #HIGH }],
        identification: [{ position: 60 }]
      }
      @EndUserText.label: 'Tasa (%)'
      Rate,
      @UI: {
        lineItem:       [{ position: 70 }],
        selectionField: [{ position: 50 }],
        identification: [{ position: 70 }]
      }
      @EndUserText.label: 'Gross Up'
      GrossUp,
      @UI: {
        lineItem:       [{ position: 80 }],
        identification: [{ position: 80 }]
      }
      @EndUserText.label: 'Especificidad'
      SpecificityScore,
      @UI: {
        lineItem:       [{ position: 90, importance: #MEDIUM }],
        identification: [{ position: 90 }]
      }
      @EndUserText.label: 'Vigente Desde'
      ValidFrom,
      @UI: {
        lineItem:       [{ position: 100, importance: #MEDIUM }],
        identification: [{ position: 100 }]
      }
      @EndUserText.label: 'Vigente Hasta'
      ValidTo,
      @UI: {
        lineItem:       [{ position: 110, importance: #HIGH, criticality: 'TxStatusCriticality' }],
        selectionField: [{ position: 60 }],
        identification: [{ position: 110 }]
      }
      @EndUserText.label: 'Estado'
      TxStatus,
      @UI.hidden: true
      TxStatusCriticality,
      @EndUserText.label: 'Descripcion'
      @UI.identification: [{ position: 120 }]
      Description,
      @EndUserText.label: 'Notas'
      @UI.identification: [{ position: 130 }]
      Notes,
      @UI.hidden: true
      CreatedBy,
      @UI.hidden: true
      CreatedAt,
      @UI.hidden: true
      ChangedBy,
      @UI.hidden: true
      ChangedAt,
      @UI.hidden: true
      LocalLastChangedAt,
      _TaxType,
      _Country,
      _Material,
      _Supplier,
      _CountryPrest,
      _CompPrest,
      _CompRecv
}
