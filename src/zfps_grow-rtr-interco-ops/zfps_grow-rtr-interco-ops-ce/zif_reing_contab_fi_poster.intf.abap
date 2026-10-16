*----------------------------------------------------------------------*
* Created by     : equipo F4 (CONTAB)                                  *
* Requirement N° :                                                     *
* Date           : 14.07.2026                                          *
* Description    : App CONTAB - Contabilizacion IC - F4 Contrato posteo FI *
* Transport      : DS4K9B5XZC                                          *
* Reference      : 5000049390                                          *
*----------------------------------------------------------------------*
* Frontera Clean Core <-> BAPIs clasicas de FI.
*
* CONTEXTO (decision de arquitectura 14.07.2026): SAP indico usar las
* BAPIs clasicas BAPI_ACC_DOCUMENT_CHECK/POST/REV_POST (ET SS8.13). En
* ABAP Cloud restricted esas BAPIs NO compilan. Para no romper el Clean
* Core de TODO el paquete (hoy 100% Cloud Development), se AISLA el uso de
* BAPIs en una unica clase Standard ABAP (ZCL_REING_CONTAB_FI_POSTER) que
* implementa esta interface. El resto (Engine, clase procesadora) sigue
* en Cloud Development y solo conoce esta interface con tipos propios;
* nunca ve una estructura BAPI. Asi la "isla" Standard ABAP es minima y
* la superficie de excepcion al Clean Core es 1 sola clase.
*
* Esta interface es Cloud-safe: no referencia ningun tipo BAPI.
*----------------------------------------------------------------------*
INTERFACE zif_reing_contab_fi_poster PUBLIC.

  "! Postea / valida / anula un documento FI via BAPI clasica.
  "! @parameter is_header | cabecera interna (tipos propios, no BAPI)
  "! @parameter it_items  | lineas BSEG internas
  "! @parameter iv_mode   | C=Check, P=Post, S=Storno
  "! @parameter rs_result | belnr/gjahr/has_error/error_msg
  METHODS post_document
    IMPORTING
      is_header        TYPE zif_reing_contab_types=>ty_header
      it_items         TYPE zif_reing_contab_types=>ty_doc_item_t
      iv_mode          TYPE zreing_ca_contab_mode
    RETURNING
      VALUE(rs_result) TYPE zif_reing_contab_types=>ty_bapi_result.

  "! Anula un documento FI existente via BAPI_ACC_DOCUMENT_REV_POST.
  "! Recibe los datos del documento original (identificado por belnr+bukrs
  "! +gjahr) y el motivo/fecha de estorno. Devuelve en rs_result-belnr el
  "! numero del documento de anulacion generado por SAP.
  "! @parameter iv_belnr        | BELNR del documento original
  "! @parameter iv_bukrs        | sociedad del documento original
  "! @parameter iv_gjahr        | ejercicio del documento original
  "! @parameter iv_reason       | motivo de estorno SAP (STGRD)
  "! @parameter iv_pstng_date   | fecha de contabilizacion del estorno
  "! @parameter rs_result       | reverse belnr / has_error / error_msg
  METHODS reverse_document
    IMPORTING
      iv_belnr         TYPE belnr_d
      iv_bukrs         TYPE bukrs
      iv_gjahr         TYPE gjahr
      iv_reason        TYPE stgrd
      iv_pstng_date    TYPE budat
    RETURNING
      VALUE(rs_result) TYPE zif_reing_contab_types=>ty_bapi_result.

ENDINTERFACE.
