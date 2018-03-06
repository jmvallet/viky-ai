$ = require('jquery');

class DeleteEntitiesListForm
  constructor: ->
    $('body').on 'modal:load', (event) =>
      @setup() if $("#modal_container .js-delete-validation").length == 1

  setup: ->
    if $('.field_with_errors input').length == 0
      App.FocusInput.atEnd('#input-delete-validation')
    else
      App.FocusInput.atEnd('.field_with_errors input')

Setup = ->
  if $('body').data('controller-name') == "entities_lists"
    new DeleteEntitiesListForm()

$(document).on('turbolinks:load', Setup)
