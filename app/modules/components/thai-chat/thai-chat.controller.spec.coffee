###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "ThaiChatCtrl", ->
    $controller = $rootScope = $sanitize = $timeout = compile = provide = null
    mocks = {}

    STORAGE_KEY = "thai_chat_messages"
    STORAGE_KEY_WIDTH = "thai_chat_width"
    CHAT_URL = "https://agente.exemplo.test/chat"
    TOKEN = "token-de-teste"

    _mockCurrentUserService = ->
        mocks.currentUserService = {
            isAuthenticated: sinon.stub().returns(true)
        }
        provide.value "tgCurrentUserService", mocks.currentUserService

    _mockStorage = ->
        mocks.storage = {
            get: sinon.stub()
        }
        mocks.storage.get.withArgs("token").returns(TOKEN)
        provide.value "$tgStorage", mocks.storage

    _mockConfig = ->
        mocks.config = {
            get: sinon.stub()
        }
        mocks.config.get.withArgs("chatStreamUrl").returns(CHAT_URL)
        provide.value "$tgConfig", mocks.config

    _mockLocation = ->
        mocks.location = {
            path: sinon.stub().returns("/")
        }
        provide.value "$tgLocation", mocks.location

    _mockProjectService = ->
        provide.value "tgProjectService", {}

    # Chave única devolve a própria chave; lista devolve mapa vazio (sugestões)
    _mockTranslate = ->
        mocks.translate = sinon.spy (keys) ->
            value = if angular.isArray(keys) then {} else keys
            return {then: (callback) -> callback(value)}
        provide.value "$translate", mocks.translate

    _mockTranslateFilter = ->
        provide.value "translateFilter", (value) -> value

    _mocks = ->
        module ($provide) ->
            provide = $provide
            _mockCurrentUserService()
            _mockStorage()
            _mockConfig()
            _mockLocation()
            _mockProjectService()
            _mockTranslate()
            _mockTranslateFilter()
            return null

    _inject = ->
        inject (_$controller_, _$rootScope_, _$sanitize_, _$compile_, _$timeout_) ->
            $controller = _$controller_
            $rootScope = _$rootScope_
            $sanitize = _$sanitize_
            compile = _$compile_
            $timeout = _$timeout_

    _clearStorage = ->
        sessionStorage.removeItem(STORAGE_KEY)
        sessionStorage.removeItem(STORAGE_KEY_WIDTH)

    _createController = ->
        return $controller("ThaiChatCtrl", {
            $scope: $rootScope.$new()
        })

    _compileFab = ->
        scope = $rootScope.$new()
        elm = compile("<div tg-thai-chat-fab></div>")(scope)
        scope.$apply()
        return elm

    _stubFetch = (result) ->
        response = {
            ok: true
            body: {
                getReader: -> {
                    read: -> Promise.resolve({done: true, value: undefined})
                }
            }
        }
        sinon.stub(window, "fetch").returns(result or Promise.resolve(response))

    # Deixa a cadeia de promessas nativas do fetch terminar e dispara o $timeout do erro
    _sendAndSettle = (ctrl, text) ->
        ctrl.input = text
        ctrl.send()
        return new Promise((resolve) -> setTimeout(resolve, 0)).then ->
            $timeout.flush()
            return ctrl

    _expectFriendlyError = (ctrl) ->
        last = ctrl.messages[ctrl.messages.length - 1]
        expect(ctrl.messages.length).to.be.equal(2)
        expect(last.role).to.be.equal("assistant")
        expect(last.content).to.be.equal("THAI_CHAT.ERROR")
        expect(last.content).not.to.match(/\d/)
        expect(ctrl.loading).to.be.false
        expect(ctrl.showTyping).to.be.false

    beforeEach ->
        module "templates"
        module "ngSanitize"
        module "taigaComponents"

        _mocks()
        _inject()
        _clearStorage()

    afterEach ->
        window.fetch.restore() if window.fetch.restore
        _clearStorage()

    it "usuário autenticado vê o botão flutuante", ->
        elm = _compileFab()

        expect(elm.find(".thai-chat-fab").length).to.be.equal(1)
        expect(elm.isolateScope().vm.isAuthenticated()).to.be.true

    it "usuário deslogado não vê o botão nem chama o agente ao enviar", ->
        mocks.currentUserService.isAuthenticated.returns(false)
        _stubFetch()

        elm = _compileFab()
        expect(elm.find(".thai-chat-fab").length).to.be.equal(0)

        ctrl = _createController()
        ctrl.input = "qual o status do projeto?"
        ctrl.send()

        expect(ctrl.isAuthenticated()).to.be.false
        expect(window.fetch).not.to.have.been.called
        expect(ctrl.messages.length).to.be.equal(0)

    it "envio manda ao agente só o token de sessão e o texto da mensagem", ->
        _stubFetch()

        ctrl = _createController()
        ctrl.input = "  qual o status do projeto?  "
        ctrl.send()

        expect(window.fetch).to.have.been.calledOnce
        [url, options] = window.fetch.firstCall.args

        expect(url).to.be.equal(CHAT_URL)
        expect(options.method).to.be.equal("POST")
        expect(Object.keys(options.headers)).to.have.members(["Content-Type", "Authorization"])
        expect(options.headers["Authorization"]).to.be.equal("Bearer #{TOKEN}")
        expect(JSON.parse(options.body)).to.be.eql({message: "qual o status do projeto?"})
        expect(ctrl.messages[0]).to.be.eql({role: "user", content: "qual o status do projeto?"})

    it "resposta em markdown vira HTML", ->
        ctrl = _createController()
        assistantMsg = {role: "assistant", content: "", html: ""}

        ctrl._applyChunk(assistantMsg, "**negrito**\n\n- item\n\n[site](https://exemplo.test)")

        expect(assistantMsg.html).to.include("<strong>negrito</strong>")
        expect(assistantMsg.html).to.include("<li>item</li>")
        expect(assistantMsg.html).to.include('href="https://exemplo.test"')

    it "resposta com script, atributo de evento e link javascript chega à tela sem eles", ->
        perigoso = [
            "**ok**"
            "<script>alert(1)</script>"
            '<img src="x" onerror="alert(1)">'
            "[link](javascript:alert(1))"
        ].join("\n\n")

        ctrl = _createController()
        assistantMsg = {role: "assistant", content: "", html: ""}
        ctrl._applyChunk(assistantMsg, perigoso)

        sanitizado = $sanitize(assistantMsg.html)
        expect(sanitizado).to.include("<strong>ok</strong>")
        expect(sanitizado).not.to.include("<script")
        expect(sanitizado).not.to.include("onerror")
        expect(sanitizado).not.to.include("javascript:")

        sessionStorage.setItem(STORAGE_KEY, JSON.stringify([{role: "assistant", content: perigoso}]))
        elm = _compileFab()
        vm = elm.isolateScope().vm
        vm.isOpen = true
        elm.isolateScope().$apply()

        bolha = elm.find(".thai-chat-bubble.--md")
        expect(bolha.length).to.be.equal(1)
        expect(bolha.html()).to.include("<strong>ok</strong>")
        expect(bolha.html()).not.to.include("<script")
        expect(bolha.html()).not.to.include("onerror")
        expect(bolha.html()).not.to.include("javascript:")

    it "agente respondendo 500 mostra mensagem amigável sem código e o chat aceita nova mensagem", ->
        _stubFetch(Promise.resolve({ok: false, status: 500}))

        _sendAndSettle(_createController(), "oi").then (ctrl) ->
            _expectFriendlyError(ctrl)

            ctrl.input = "de novo"
            ctrl.send()
            expect(window.fetch).to.have.been.calledTwice

    it "agente respondendo 404 mostra a mesma mensagem amigável sem código", ->
        _stubFetch(Promise.resolve({ok: false, status: 404}))

        _sendAndSettle(_createController(), "oi").then (ctrl) ->
            _expectFriendlyError(ctrl)

    it "falha de rede mostra a mesma mensagem amigável e o chat aceita nova mensagem", ->
        _stubFetch(Promise.reject(new TypeError("Failed to fetch")))

        _sendAndSettle(_createController(), "oi").then (ctrl) ->
            _expectFriendlyError(ctrl)

            ctrl.input = "de novo"
            ctrl.send()
            expect(window.fetch).to.have.been.calledTwice

    it "sem chatStreamUrl nenhuma requisição sai, o chat responde indisponível e o botão continua", ->
        mocks.config.get.withArgs("chatStreamUrl").returns(undefined)
        _stubFetch()

        elm = _compileFab()
        expect(elm.find(".thai-chat-fab").length).to.be.equal(1)

        ctrl = _createController()
        ctrl.input = "oi"
        ctrl.send()

        expect(window.fetch).not.to.have.been.called
        expect(ctrl.messages.length).to.be.equal(2)
        expect(ctrl.messages[0]).to.be.eql({role: "user", content: "oi"})
        expect(ctrl.messages[1].role).to.be.equal("assistant")
        expect(ctrl.messages[1].content).to.be.equal("THAI_CHAT.UNAVAILABLE")
        expect(ctrl.loading).to.be.false

    it "chatStreamUrl vazio é tratado como ausente", ->
        mocks.config.get.withArgs("chatStreamUrl").returns("")
        _stubFetch()

        ctrl = _createController()
        ctrl.input = "oi"
        ctrl.send()

        expect(window.fetch).not.to.have.been.called
        expect(ctrl.messages[1].content).to.be.equal("THAI_CHAT.UNAVAILABLE")

    it "logout zera as mensagens e limpa o sessionStorage", ->
        ctrl = _createController()
        ctrl.messages.push({role: "user", content: "oi"})
        ctrl._saveMessages()
        sessionStorage.setItem(STORAGE_KEY_WIDTH, "640")
        ctrl.isOpen = true

        $rootScope.$broadcast("auth:logout")

        expect(ctrl.messages.length).to.be.equal(0)
        expect(ctrl.isOpen).to.be.false
        expect(sessionStorage.getItem(STORAGE_KEY)).to.be.null
        expect(sessionStorage.getItem(STORAGE_KEY_WIDTH)).to.be.null
