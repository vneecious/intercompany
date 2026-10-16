@AbapCatalog.viewEnhancementCategory: [#NONE]
// Ajustado: #NOT_REQUIRED si no hay lógica de autorización compleja para este catálogo
// Si necesitas control de acceso, aquí iría #CHECK o se enlazaría a una DCL (Data Control Language)
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intracompany Document Type Catalog Interface' // Ajustado ligeramente el label
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #A,
    sizeCategory: #S,    // Pequeño conjunto de datos (catálogos suelen ser pequeños)
    // Para catálogos, #MASTER (datos maestros) o #REFERENCE (datos de referencia) son más adecuados que #MIXED
    dataClass: #MASTER   // Datos maestros / de catálogo
}
define view entity ZI_IntrcDocType_C
  as select from zfi_a_intrc_dtyp
{
      //  key client        as Client,        // Mandante
  key dtyp_id       as DocumentTypeID, // ID del tipo de documento
  key language_code as LanguageCode,    // Código de idioma
      dtyp_name     as DocumentTypeName // Nombre/Descripción del tipo de documento
}
