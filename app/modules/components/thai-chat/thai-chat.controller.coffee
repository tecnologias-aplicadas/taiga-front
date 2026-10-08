###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

CLOSE_ANIMATION_MS = 400

# Chaves de sugestão por contexto de rota
# Para adicionar perguntas: inclua novas chaves aqui e nas locales
SUGGESTION_KEYS =
    projects: [
        "THAI_CHAT.SUGGESTIONS.PROJECTS_0"
        "THAI_CHAT.SUGGESTIONS.PROJECTS_1"
    ]
    project: [
        "THAI_CHAT.SUGGESTIONS.PROJECT_0"
        "THAI_CHAT.SUGGESTIONS.PROJECT_1"
        "THAI_CHAT.SUGGESTIONS.PROJECT_2"
        "THAI_CHAT.SUGGESTIONS.PROJECT_2"
    ]
    profile: [
        "THAI_CHAT.SUGGESTIONS.PROFILE_0"
        "THAI_CHAT.SUGGESTIONS.PROFILE_1"
        "THAI_CHAT.SUGGESTIONS.PROFILE_2"
    ]

class ThaiChatController
    @.$inject = [
        "$http",
        "$timeout",
        "$translate",
        "$tgLocation",
        "tgProjectService",
        "tgCurrentUserService",
        "$tgStorage",
        "$rootScope",
        "$tgConfig"
    ]

    STORAGE_KEY = "thai_chat_messages"
    STORAGE_KEY_WIDTH = "thai_chat_width"
    DEFAULT_WIDTH = 506
    MIN_WIDTH = 320

    constructor: (@http, @timeout, @translate, @location, @projectService, @currentUserService, @storage, @rootScope, @config) ->
        @.chatStreamUrl = @config.get("chatStreamUrl")
        @.messages = @._loadMessages()
        @.input = ""
        @.loading = false
        @.showTyping = false
        @._typingTimer = null
        @.isOpen = false
        @.isClosing = false
        @.suggestions = []
        @.defaultWidth = DEFAULT_WIDTH
        savedWidth = parseInt(sessionStorage.getItem(STORAGE_KEY_WIDTH), 10)
        @.panelWidth = if isNaN(savedWidth) then DEFAULT_WIDTH else savedWidth

        @rootScope.$on "auth:logout", () =>
            @._reset()

    _saveMessages: () ->
        raw = @.messages.map (m) -> { role: m.role, content: m.content }
        sessionStorage.setItem(STORAGE_KEY, JSON.stringify(raw))

    _loadMessages: () ->
        try
            raw = JSON.parse(sessionStorage.getItem(STORAGE_KEY) or "[]")
            return raw.map (m) =>
                html = if m.role is "assistant" then window.marked.parse(m.content or "") else null
                { role: m.role, content: m.content, html: html }
        catch e
            return []

    _reset: () ->
        @._stopTyping()
        sessionStorage.removeItem(STORAGE_KEY)
        sessionStorage.removeItem(STORAGE_KEY_WIDTH)
        @.messages = []
        @.input = ""
        @.loading = false
        @.isOpen = false
        @.isClosing = false
        @.suggestions = []
        @.panelWidth = DEFAULT_WIDTH

    resetSize: () ->
        @.panelWidth = DEFAULT_WIDTH
        sessionStorage.removeItem(STORAGE_KEY_WIDTH)

    startResize: (event) ->
        event.preventDefault()
        startX = event.clientX
        startWidth = @.panelWidth
        maxWidth = Math.round(window.innerWidth * 0.9)

        onMove = (e) =>
            delta = startX - e.clientX
            newWidth = Math.round(Math.min(Math.max(startWidth + delta, MIN_WIDTH), maxWidth))
            if newWidth isnt @.panelWidth
                @.panelWidth = newWidth
                @rootScope.$applyAsync() if not @rootScope.$$phase

        onUp = () =>
            document.removeEventListener('mousemove', onMove)
            document.removeEventListener('mouseup', onUp)
            sessionStorage.setItem(STORAGE_KEY_WIDTH, @.panelWidth)

        document.addEventListener('mousemove', onMove)
        document.addEventListener('mouseup', onUp)

    isAuthenticated: () ->
        @currentUserService.isAuthenticated()

    _detectContext: () ->
        path = @location.path()
        if /^\/profile/.test(path)
            return "profile"
        else if /^\/project\/[^/]+/.test(path)
            return "project"
        else
            return "projects"

    _loadSuggestions: () ->
        context = @._detectContext()
        keys = SUGGESTION_KEYS[context] or []
        @translate(keys).then (translations) =>
            @.suggestions = keys.map (k) -> translations[k]

    toggleChat: () ->
        if @.isOpen
            @.isClosing = true
            @timeout (() =>
                @.isOpen = false
                @.isClosing = false
            ), CLOSE_ANIMATION_MS
        else
            @.isOpen = true
            @._loadSuggestions()
            @timeout () =>
                @._scrollToBottom()
            , 0

    clearChat: () ->
        @._stopTyping()
        sessionStorage.removeItem(STORAGE_KEY)
        @.messages = []
        @.loading = false
        @._loadSuggestions()

    sendSuggestion: (text) ->
        @.input = text
        @.send()

    _scrollToBottom: () ->
        @rootScope.$$postDigest () ->
            el = document.querySelector('.thai-chat-messages')
            if el
                el.scrollTop = el.scrollHeight

    _startTypingDelay: () ->
        if @._typingTimer
            @timeout.cancel(@._typingTimer)
        @._typingTimer = @timeout () =>
            @.showTyping = true
        , 500

    _stopTyping: () ->
        if @._typingTimer
            @timeout.cancel(@._typingTimer)
            @._typingTimer = null
        @.showTyping = false

    _applyChunk: (assistantMsg, chunk) ->
        @._stopTyping()
        assistantMsg.content += chunk
        assistantMsg.html = window.marked.parse(assistantMsg.content)
        @._saveMessages()
        @._startTypingDelay()
        @._scrollToBottom()

    _processLines: (lines, assistantMsg) ->
        for raw in lines
            raw = raw.trim()
            continue if not raw or raw.startsWith("Connected to")
            raw = raw.replace(/^data:\s*/, "")
            continue if not raw
            return true if raw == "[DONE]"
            try
                data = JSON.parse(raw)
                chunk = data?.choices?[0]?.delta?.content
                if chunk
                    do (chunk) =>
                        @timeout () =>
                            @._applyChunk(assistantMsg, chunk)
                        , 0
            catch e
                # linha não-JSON ignorada
        return false

    send: () ->
        return if not @.isAuthenticated()
        text = @.input?.trim()
        return if not text or @.loading

        @.messages.push({ role: "user", content: text })
        @._saveMessages()
        @.input = ""
        @timeout () ->
            el = document.querySelector('.thai-chat-footer textarea')
            if el
                el.style.height = 'auto'
                el.style.overflowY = 'hidden'
        , 0
        @._scrollToBottom()

        # Ambiente sem endereço do agente: responde sem sair do navegador
        if not @.chatStreamUrl
            @._replyWith("THAI_CHAT.UNAVAILABLE")
            return

        @.loading = true
        @._startTypingDelay()

        token = @storage.get("token")
        assistantMsg = { role: "assistant", content: "", html: "" }
        @.messages.push(assistantMsg)
        @._scrollToBottom()

        # Qualquer falha (HTTP, rede) vira a mesma mensagem amigável, sem detalhe técnico
        onError = () =>
            @._stopTyping()
            @timeout () =>
                @.loading = false
                if not assistantMsg.content
                    @.messages.splice(@.messages.indexOf(assistantMsg), 1)
                    @._replyWith("THAI_CHAT.ERROR")
            , 0

        fetch(@.chatStreamUrl, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Authorization": "Bearer #{token}"
            },
            body: JSON.stringify({ message: text })
        }).then (response) =>
            if not response.ok
                return Promise.reject(new Error("HTTP #{response.status}"))

            reader = response.body.getReader()
            decoder = new TextDecoder()
            buffer = ""

            readChunk = () =>
                reader.read().then ({ done, value }) =>
                    if value
                        buffer += decoder.decode(value, { stream: true })

                    lines = buffer.split("\n")
                    buffer = if done then "" else lines.pop()

                    streamDone = @._processLines(lines, assistantMsg)
                    @._scrollToBottom()

                    if done or streamDone
                        @timeout () =>
                            @._stopTyping()
                            @.loading = false
                            if not assistantMsg.content
                                @translate("THAI_CHAT.ERROR").then (msg) =>
                                    assistantMsg.content = msg
                                    assistantMsg.html = window.marked.parse(msg)
                        , 0
                        return Promise.resolve()

                    return readChunk()

            return readChunk()

        .catch () =>
            onError()

    _replyWith: (key) ->
        @translate(key).then (msg) =>
            @.messages.push({ role: "assistant", content: msg, html: window.marked.parse(msg) })
            @._saveMessages()
            @._scrollToBottom()

    autoResize: (event) ->
        el = event.target
        el.style.height = 'auto'
        if el.scrollHeight > 155
            el.style.height = '155px'
            el.style.overflowY = 'auto'
        else
            el.style.height = el.scrollHeight + 'px'
            el.style.overflowY = 'hidden'

    onKeydown: (event) ->
        # Enter envia; Shift+Enter quebra linha
        if event.keyCode == 13 and not event.shiftKey
            event.preventDefault()
            @.send()

angular.module("taigaComponents").controller("ThaiChatCtrl", ThaiChatController)
