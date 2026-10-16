@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CM - Distribucion del Tipo de Operacion'
@ObjectModel.usageType.serviceQuality: #C
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #MIXED

// ----------------------------------------------------------------------
// Autor  : EXT_AGFAGINA
// Fecha  : 08.09.2026
// Motivo : Carga Mensual necesita mostrar la DISTRIBUCION del devengamiento
//          (L = Lineal / E = Espacial) que se configuro en el contrato.
//
//          El campo "Tipo Dev." que ya existe en CM es otra cosa: guarda
//          P (Padron) / B (Bonificacion), viene de la columna Bonif del Excel
//          y de el dependen tres validaciones (BR-CM-12, BR-CM-13 y la que
//          exige P o B en toda Activacion). Por eso no se reutiliza ese campo:
//          se expone la distribucion aparte, derivada y de solo lectura.
//
// Nota   : ZREING_CM_H_A no tiene OP_INSTANCE_NUM, asi que un registro de CM
//          puede corresponder a varias instancias del mismo tipo de operacion
//          en el contrato (A/001, A/002...). Se agrupa por contrato + material
//          + tipo y se toma un valor determinista con MAX.
//          Si dos instancias del mismo tipo tuvieran distinta distribucion, se
//          muestra una sola. Es un campo informativo, no participa de ningun
//          calculo ni validacion.
// ----------------------------------------------------------------------
define view entity ZI_ReingCMOpTypeDist
  as select from zreing_ct2_opt_a as Opt
{
  key Opt.ct_uuid           as CtUuid,
  key Opt.mat_uuid          as MatUuid,
  key Opt.op_type           as OpType,
      // Mod 01.10.2026 EXT_AGFAGINA - defecto 109: se resuelve por INSTANCIA. Antes
      // CM no tenia OP_INSTANCE_NUM y con dos activaciones en el contrato (ej.
      // IC-0001: A 002 y A 003) el MAX devolvia la distribucion de una cualquiera.
  key Opt.op_instance_num   as OpInstanceNum,
      max( Opt.dist_type )  as DistType,
      max( Opt.defer_from ) as DeferFrom,
      max( Opt.defer_to )   as DeferTo
}
group by
  Opt.ct_uuid,
  Opt.mat_uuid,
  Opt.op_type,
  Opt.op_instance_num
