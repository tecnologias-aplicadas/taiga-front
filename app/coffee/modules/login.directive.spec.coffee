###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "tgLogin", () ->
    scope = compile = provide = template = null
    mocks = {}

    _mockTgLoader = () ->
        mocks.loader = {
            start: sinon.stub()
            pageLoaded: sinon.stub()
        }
        provide.value "tgLoader", mocks.loader

    _mockLightboxService = () ->
        mocks.lightboxService = {
            open: sinon.stub()
            close: sinon.stub()
        }
        provide.value "lightboxService", mocks.lightboxService

    # tg-nav, usado pelos links da tela, pede este
    _mockTgSections = () ->
        mocks.sections = {
            getPath: sinon.stub().returns("backlog")
        }
        provide.value "$tgSections", mocks.sections

    _mockTgAuth = () ->
        mocks.auth = {
            login: sinon.stub().promise()
            getUser: sinon.stub().returns(null)
        }
        provide.value "$tgAuth", mocks.auth

    _mockTgConfirm = () ->
        mocks.confirm = {
            notify: sinon.stub()
        }
        provide.value "$tgConfirm", mocks.confirm

    _mockTgLocation = () ->
        mocks.location = {
            path: sinon.stub()
            url: sinon.stub()
        }
        provide.value "$tgLocation", mocks.location

    _mockTgConfig = () ->
        mocks.config = {
            get: sinon.stub()
        }
        provide.value "$tgConfig", mocks.config

    _mockRouteParams = () ->
        provide.value "$routeParams", {}

    _mockTgNavUrls = () ->
        mocks.navUrls = {
            resolve: sinon.stub().returns("/")
            # o módulo base registra as rotas no run block
            update: sinon.stub()
        }
        provide.value "$tgNavUrls", mocks.navUrls

    _mockTgEvents = () ->
        mocks.events = {
            setupConnection: sinon.stub()
        }
        provide.value "$tgEvents", mocks.events

    _mockTgAnalytics = () ->
        mocks.analytics = {
            trackEvent: sinon.stub()
        }
        provide.value "$tgAnalytics", mocks.analytics

    _mockTranslate = () ->
        mocks.translate = {
            instant: sinon.stub().returnsArg(0)
        }
        provide.value "$translate", mocks.translate

    _mockTranslateFilter = () ->
        mockTranslateFilter = (value) -> value
        provide.value "translateFilter", mockTranslateFilter

    _mocks = () ->
        module ($provide) ->
            provide = $provide
            _mockTgLoader()
            _mockLightboxService()
            _mockTgSections()
            _mockTgAuth()
            _mockTgConfirm()
            _mockTgLocation()
            _mockTgConfig()
            _mockRouteParams()
            _mockTgNavUrls()
            _mockTgEvents()
            _mockTgAnalytics()
            _mockTranslate()
            _mockTranslateFilter()
            return null

    createDirective = () ->
        elm = compile(template)(scope)
        scope.$apply()
        return elm

    # o login externo é o que não depende do LDAP
    submitExternalForm = (elm) ->
        form = elm.find("form.login-form-external")
        form.find("input[name=username]").val("user")
        form.find("input[name=password]").val("password")
        form.trigger("submit")

        return form

    beforeEach ->
        module "templates"
        module "taigaAuth"

        _mocks()

        inject ($rootScope, $compile, $templateCache) ->
            scope = $rootScope.$new()
            compile = $compile
            # o formulário real da tela de login, para o teste falhar se a tela mudar.
            # parseHTML descarta o script do reCAPTCHA, que não se carrega no teste.
            nodes = $.parseHTML($templateCache.get("auth/login.html"))
            template = $("<div></div>").append(nodes).find(".login-form-container")[0].outerHTML

    ERROR_CODES = {
        "invalid_credentials": "LOGIN_COMMON.INVALID_CREDENTIALS"
        "undefined_credentials": "LOGIN_COMMON.UNDEFINED_CREDENTIALS"
        "invalid_recaptcha": "LOGIN_COMMON.INVALID_RECAPTCHA"
        "invitation_email_mismatch": "INVITATION_LOGIN_FORM.EMAIL_MISMATCH"
        "invitation_not_valid": "INVITATION_LOGIN_FORM.NOT_VALID"
        "already_project_member": "INVITATION_LOGIN_FORM.ALREADY_MEMBER"
        "user_does_not_exist": "INVITATION_LOGIN_FORM.USER_NOT_FOUND"
    }

    Object.keys(ERROR_CODES).forEach (code) ->
        it "translates the code #{code}", () ->
            elm = createDirective()
            submitExternalForm(elm)

            expect(mocks.auth.login).to.have.been.called
            mocks.auth.login.reject({data: {code: code}})

            return Promise.resolve().then ->
                expect(mocks.confirm.notify).to.have.been.calledWith("light-error", ERROR_CODES[code])

    it "keeps the generic message when the server sends no code", () ->
        elm = createDirective()
        submitExternalForm(elm)

        mocks.auth.login.reject({data: {_error_message: "algo deu errado"}})

        return Promise.resolve().then ->
            expect(mocks.confirm.notify).to.have.been.calledWith("light-error", "COMMON.GENERIC_ERROR")

    it "keeps showing the detail the server sends", () ->
        elm = createDirective()
        submitExternalForm(elm)

        mocks.auth.login.reject({data: {detail: "muitas tentativas"}})

        return Promise.resolve().then ->
            expect(mocks.confirm.notify).to.have.been.calledWith("light-error", "muitas tentativas")
