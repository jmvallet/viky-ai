require 'slick-carousel/slick/slick.css';
require 'slick-carousel/slick/slick-theme.css';
require 'slick-carousel';

class Chat
  constructor: ->
    new ButtonGroups()
    List.generateAll()
    Statement.init_ui()

    new StatementHistory($('.chatbot').data('history-url'))

    @recognition = new Recognition()
    @geolocator = new Geolocator()

    if @recognition.available
      $('.bot-form .btn--recognition').show()
      $('.bot-form .dropdown').show()

      $("body").on 'click', (event) => @dispatch(event)

      $('body').on 'recognition:update_locale', (event) =>
        locale = $('.chatbot').data('recognition-locale')
        $('#locales-dropdown a').removeClass('current')
        $("#locales-dropdown a[data-locale='#{locale}']").addClass('current')
        $('#locales-dropdown .dropdown__trigger code').html(locale)
        @recognition = new Recognition()

      $('body').on 'recognition:result', (event, transcript) =>
        $("#statement_content").val(transcript)
        form = document.querySelector(".bot-form");
        Rails.fire(form, 'submit')

      $("body").on 'recognition:start', (event) =>
        $('.btn--recognition').addClass('btn--recognition-on')

      $("body").on 'recognition:stop', (event) =>
        $('.btn--recognition').removeClass('btn--recognition-on')
    else
      $('.btn--recognition').remove()
      $('.bot-form .dropdown').remove()


    $("body").on 'ajax:before', (event) =>
      node  = $(event.target)
      if node.hasClass('chatbot__widget--geolocation')
        if !@geolocator.is_location_valid(node)
          @geolocator.locate_user()
            .then((location) ->
              node.trigger('geolocation:locate', location)
            )
            .catch((error) ->
              node.trigger('geolocation:error', error)
            )
          return false
    $("body").on 'geolocation:locate', (event, location) =>
      node = $(event.target)
      @geolocator.set_form_location(node, location)
      @geolocator.set_periodic_prefetch()
      form = node[0]
      Rails.fire(form, 'submit')
    $("body").on 'geolocation:error', (event, error) =>
      node = $(event.target)
      @geolocator.set_form_error(node, error)
      @geolocator.clear_periodic_prefetch()
      form = node[0]
      Rails.fire(form, 'submit')
    $("body").on 'ajax:complete', (event) =>
      node  = $(event.target)
      if node.hasClass('chatbot__widget--geolocation')
        @geolocator.clear_form_location(node)

  dispatch: (event) ->
    node  = $(event.target)
    action = node.data('action')
    if not action?
      node = $(event.target).parents('button')
      action = node.data('action')

    if action == "recognition-toggle"
      event.preventDefault()
      if node.hasClass('btn--recognition-on')
        @recognition.stop()
      else
        @recognition.start()


class StatementHistory
  constructor: (url) ->
    @url = url
    @history = []
    @history_pointer = -1
    @last_fetch_was_empty = false
    @fetch_all()
    @set_listeners()

  set_listeners: =>
    $('.bot-form').on 'submit', (event) =>
      @add($('#statement_content').val())
      @reset_pointer()

    $('#statement_content').on 'keydown', (event) =>
      if event.which == 38
        event.preventDefault()
        $('#statement_content').val(@previous())
      if event.which == 40
        event.preventDefault()
        $('#statement_content').val(@next())

  reset_pointer: ->
    @history_pointer = -1

  add: (statement) ->
    @history.unshift(statement)

  previous: () ->
    need_to_fetch_ahead = @history_pointer + 3 == @history.length
    @fetch_all() if need_to_fetch_ahead
    if @history_pointer + 1 >= @history.length
      @history_pointer = @history.length
      value = ''
    else
      @history_pointer++
      value = @history[@history_pointer]
    return value

  next: () ->
    if @history_pointer - 1 < 0
      @history_pointer = -1
      value = ''
    else
      @history_pointer--
      value = @history[@history_pointer]
    return value

  fetch_all: () ->
    return if @last_fetch_was_empty
    $.ajax({
      url: @url,
      method: 'GET',
      data: { start: @history.length }
    }).then((statements) =>
      @last_fetch_was_empty = statements.length == 0
      statements.forEach((statement) => @history.push(statement.content.text))
    )


class Speaker
  say: (text, locale) ->
    if (window.speechSynthesis)
      Speaker = window.speechSynthesis
      speech_request = new SpeechSynthesisUtterance();
      voices = Speaker.getVoices()

      for voice in voices
        if voice.lang == locale || voice.lang == locale.replace('-', '_')
          speech_request.voice = voice
          break

      speech_request.volume = 1
      speech_request.text = text
      speech_request.lang = locale
      Speaker.speak(speech_request)

  quiet: () ->
    if (window.speechSynthesis)
      Speaker = window.speechSynthesis
      Speaker.cancel()


class Geolocator
  constructor: () ->
    @interval_id = null
    if navigator.geolocation
      @geolocation = navigator.geolocation

  locate_user: () ->
    return new Promise((resolve, reject) =>
      @geolocation.getCurrentPosition(resolve, reject)
    )

  set_periodic_prefetch: () ->
    if @interval_id == null
      @interval_id = setInterval(() =>
        nodes = $('form.chatbot__widget--geolocation')
        @locate_user()
          .then((location) =>
            nodes.each((index, node) =>
              @set_form_location(node, location)
            )
          )
          .catch((error) =>
            @clear_periodic_prefetch()
            nodes.each((index, node) =>
              @clear_form_location(node)
            )
          )
      , 5*60*1000)

  clear_periodic_prefetch: () ->
    if @interval_id != null
      clearInterval(@interval_id)
      @interval_id = null

  set_form_location: (form, location) ->
    @form_status(form).value = 'success'
    @form_location(form).value = JSON.stringify({
      coords: {
        accuracy: location.coords.accuracy,
        altitude: location.coords.altitude,
        altitudeAccuracy: location.coords.altitudeAccuracy,
        heading: location.coords.heading,
        latitude: location.coords.latitude,
        longitude: location.coords.longitude,
        speed: location.coords.speed,
      },
      timestamp: location.timestamp
    })

  set_form_error: (form, error) ->
    @form_status(form).value = 'error'
    @form_location(form).value = JSON.stringify({
      code: error.code,
      message: error.message
    })

  clear_form_location: (form) ->
    @form_status(form).value = ''
    @form_location(form).value = ''

  is_location_valid: (form) ->
    return @form_location(form).value != ''

  form_location: (form) ->
    return $(form).find('[name=location]')[0]

  form_status: (form) ->
    return $(form).find('[name=status]')[0]


class Recognition
  constructor: ->
    @available = false
    if (window.SpeechRecognition || window.webkitSpeechRecognition || window.mozSpeechRecognition || window.msSpeechRecognition)
      $("html").addClass("has-speech-recognition")
      @available = true

    if @available
      @stopped = true
      @has_result = false
      @recognition = new (window.SpeechRecognition || window.webkitSpeechRecognition || window.mozSpeechRecognition || window.msSpeechRecognition)();
      @recognition.lang = $('.chatbot').data('recognition-locale')

      @recognition.onend = (event) =>
        if @has_result || @stopped
          @recognition.stop()
          $('body').trigger('recognition:stop')
        else
          @recognition.start()

      @recognition.onresult = (event) =>
        last = event.results.length - 1;
        transcript = event.results[last][0].transcript
        if transcript == ""
          @has_result = false
        else
          @has_result = true
          $('body').trigger('recognition:result', [transcript])

  start: ->
    if @available
      @stopped = false
      @recognition.start()
      $('body').trigger('recognition:start')

  stop: ->
    if @available
      @stopped = true
      @recognition.stop()


class Statement
  constructor: (html) ->
    @html = html

  is_from_user: ->
    $(@html).hasClass('chatbot__statement--user')

  is_from_bot: ->
    $(@html).hasClass('chatbot__statement--bot')

  display: ->
    content = $(@html)
    content.find('> .chatbot__avatar').addClass('chatbot__avatar--hidden')
    content.find('> .chatbot__widget').addClass('chatbot__widget--hidden')

    $('.chatbot__discussion').append(content)

    avatar = $('.chatbot__discussion .chatbot__statement > .chatbot__avatar').last()
    widget = $('.chatbot__discussion .chatbot__statement > .chatbot__widget').last()

    List.generateLast()
    Statement.scroll_to_last()

    avatar.removeClass('chatbot__avatar--hidden')
    widget.removeClass('chatbot__widget--hidden')

    if @is_from_user()
      Statement.display_bot_waiting()
    else
      $('.chatbot__statement__waiting').closest('.chatbot__statement').remove()
      Speaker::quiet()

    speech_text = content.data("speech-text")
    if speech_text != ''
      speech_locale = content.data("speech-locale")
      Statement.speech(speech_text, speech_locale)

  @init_ui: ->
    Statement.scroll_to_last(0)
    if $('.chatbot__statement').length == 0
      Statement.display_bot_waiting()

  @display_bot_waiting: ->
    $('.chatbot__discussion').append(Statement.waiting_content())
    Statement.scroll_to_last(0)

  @scroll_to_last: (duration = 250) ->
    discussion_h = $('.chatbot__discussion').prop("scrollHeight")
    statement_h = $('.chatbot__statement').last().outerHeight()
    $(".chatbot__discussion").animate(
      { scrollTop: discussion_h - statement_h - 60}, duration
    )

  @speech: (text, locale) ->
    Speaker::say(text, locale)

  @waiting_content: ->
    html = []
    html.push '<div class="chatbot__statement chatbot__statement--bot">'
    html.push '  <div class="chatbot__statement__waiting">'
    html.push '    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 10">'
    html.push '      <path d="M4.784 7.608a2.392 2.392 0 0 1-4.784 0 2.392 2.392 0 1 1 4.784 0z" class="point-a" />'
    html.push '      <path d="M12.392 7.608a2.392 2.392 0 0 1-4.784 0 2.392 2.392 0 1 1 4.784 0z" class="point-b" />'
    html.push '      <path d="M20 7.608a2.392 2.392 0 0 1-4.784 0 2.392 2.392 0 1 1 4.784 0z" class="point-c" />'
    html.push '    </svg>'
    html.push '  </div>'
    html.push '</div>'
    html.join("\n")

  @display_js_map: (api_key, statement_id, map_options) ->
    display = () ->
      map = new google.maps.Map(document.getElementById("map-" + statement_id), map_options.map);
      if map_options.markers
        markers = map_options.markers
        bounds = new google.maps.LatLngBounds()
        markers.list.forEach((mark) ->
          marker = new google.maps.Marker({
            map: map,
            position: mark.position,
            title: mark.title
          })
          if mark.description
            infowindow = new google.maps.InfoWindow({
              content: mark.description,
              maxWidth: 350
            })
            marker.addListener('click', () ->
              infowindow.open(map, marker)
            )
          bounds.extend(marker.position)
        )
        if markers.center
          map.fitBounds(bounds)

    wait_count = 0
    wait_lib_loading = () ->
      if wait_count > 50
        console.error("Cannot load Google JavaScript library")
        return
      if !$('script[src^="https://maps.googleapis.com/maps/api/js?"]')[0].loaded
        wait_count += 1
        setTimeout(wait_lib_loading, 10*wait_count)
      else
        display()

    if $('script[src^="https://maps.googleapis.com/maps/api/js?"]').length == 0
      script = document.createElement('script')
      script.loaded = false
      script.onload = () ->
        this.loaded = true
        display()
      script.src = "https://maps.googleapis.com/maps/api/js?key=#{api_key}"
      document.head.appendChild(script)
    else
      wait_lib_loading()


class List
  constructor: (element) ->
    if $(element).find('> div').length > 2
      max = 3
    else
      max = 2

    $(element).slick(
      dots: true,
      slidesToShow: max,
      slidesToScroll: max,
      infinite: false,
      arrows: false,
      responsive: [
        {
          breakpoint: 1850,
          settings: {
            slidesToShow: 2,
            slidesToScroll: 2,
          }
        }
        {
          breakpoint: 1350,
          settings: {
            slidesToShow: 1,
            slidesToScroll: 1,
            centerMode: true,
            centerPadding: '12px',
          }
        }
      ]
    )

  @generateLast: ->
    last_widget = $('.chatbot__statement > .chatbot__widget').last()
    if $(last_widget).hasClass('chatbot__widget--list--horizontal')
      slide = $('.chatbot__widget--list--horizontal > div').last()
      new List(slide)

  @generateAll: ->
    for slide in $('.chatbot__widget--list--horizontal > div')
      new List(slide)


class ButtonGroups
  constructor: ->
    $("body").on 'ajax:send', (event) => @dispatch_ajax(event)
    $("body").on 'click', (event) => @dispatch_click(event)

  dispatch_click: (event) ->
    node  = $(event.target)
    button_group = node.closest('.chatbot__widget--button-group')
    if button_group.length == 1 && node.is(":button")
      node.attr('selected', 'selected')

  dispatch_ajax: (event) ->
    node  = $(event.target)
    button_group = node.closest('.chatbot__widget--button-group')
    if button_group.length == 1
      disable_on_click = button_group.data("disable-on-click")
      if disable_on_click
        for button in button_group.find("button")
          $(button).attr('disabled', 'disabled')

Setup = ->
  if $('body').data('controller-name') == "chatbots" && $('body').data('controller-action') == "show"
    new Chat()

$(document).on('turbolinks:load', Setup)

module.exports = Statement
