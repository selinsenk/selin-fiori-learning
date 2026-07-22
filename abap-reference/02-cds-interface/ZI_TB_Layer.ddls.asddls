/*******************************************************************************
 * ZI_TB_Layer  —  THE LAYER CODE LIST (feeds the Screen 1 dropdown)
 *
 * COMPARE WITH: the `entity Layers` block in db/schema.cds, which carried
 *               @cds.odata.valuelist for the same purpose.
 ******************************************************************************/

@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Accounting Layer - Interface View'
@Metadata.ignorePropagatedAnnotations: true

/*
 * @ObjectModel.dataCategory: #TEXT marks this as a text/code-list view.
 * @ObjectModel.representativeKey names the field that IS the code.
 *
 * These two annotations are how S/4HANA recognises a value list. Combined with
 * @ObjectModel.text.element below, any field elsewhere in the system that
 * points at LayerID can automatically show the description next to the code.
 */
@ObjectModel.dataCategory: #TEXT
@ObjectModel.representativeKey: 'LayerID'
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #CUSTOMIZING }

define view entity ZI_TB_Layer
  as select from ztb_layer
{
      /*------------------------------------------------------------------------
       * @ObjectModel.text.element declares "the human-readable text for this
       * key is in field LayerDescription".
       *
       * This is the ABAP CDS twin of what we wrote in srv/annotations.cds as:
       *      ID @( Common.Text: description, Common.TextArrangement: #TextFirst )
       *-----------------------------------------------------------------------*/
      @ObjectModel.text.element: ['LayerDescription']
  key layer_id    as LayerID,

      @Semantics.text: true
      description as LayerDescription
}
