@EndUserText.label: 'Intracompany Document Type Catalog Projection'
@Metadata.allowExtensions: true

define view entity ZC_IntrcDocType_C
  as select from zfi_a_intrc_dtyp
{
  key dtyp_id       as DocumentTypeID,  // ID del tipo de documento
  key language_code as LanguageCode,    // Código de idioma
      dtyp_name     as DocumentTypeName // Nombre/Descripción del tipo de documento
}
