###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "tgRegister", () ->
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

    # tg-nav, usado pelo link para o login, pede este
    _mockTgSections = () ->
        mocks.sections = {
            getPath: sinon.stub().returns("backlog")
        }
        provide.value "$tgSections", mocks.sections

    _mockTgAuth = () ->
        mocks.auth = {
            register: sinon.stub().promise()
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
            replace: sinon.stub()
        }
        provide.value "$tgLocation", mocks.location

    _mockTgConfig = () ->
        mocks.config = {
            get: sinon.stub()
        }
        mocks.config.get.withArgs("publicRegisterEnabled").returns(true)
        provide.value "$tgConfig", mocks.config

    _mockRouteParams = () ->
        provide.value "$routeParams", {}

    _mockTgNavUrls = () ->
        mocks.navUrls = {
            resolve: sinon.stub().returns("/login")
            # o módulo base registra as rotas no run block
            update: sinon.stub()
        }
        provide.value "$tgNavUrls", mocks.navUrls

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
            _mockTgAnalytics()
            _mockTranslate()
            _mockTranslateFilter()
            return null

    createDirective = () ->
        elm = compile(template)(scope)
        scope.$apply()
        return elm

    # preenche o formulário com dados válidos para o envio chegar ao servidor
    submitForm = (elm) ->
        form = elm.find("form.register-form")
        form.find("input[name=username]").val("new_user")
        form.find("input[name=full_name]").val("New User")
        form.find("input[name=email]").val("new_user@email.com")
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
            # o partial real da tela de cadastro, para o teste falhar se a tela mudar
            template = $templateCache.get("auth/register.html")

    ERROR_CODES = {
        "username_already_in_use": "REGISTER_FORM.USERNAME_ALREADY_IN_USE"
        "email_already_in_use": "REGISTER_FORM.EMAIL_ALREADY_IN_USE"
        "user_creation_failed": "REGISTER_FORM.USER_CREATION_FAILED"
        "public_register_disabled": "REGISTER_FORM.PUBLIC_REGISTER_DISABLED"
        "terms_not_accepted": "REGISTER_FORM.TERMS_NOT_ACCEPTED"
        "invalid_registration_type": "REGISTER_FORM.INVALID_REGISTRATION_TYPE"
    }

    Object.keys(ERROR_CODES).forEach (code) ->
        it "translates the code #{code}", () ->
            elm = createDirective()
            form = submitForm(elm)

            expect(mocks.auth.register).to.have.been.called
            mocks.auth.register.reject({data: {code: code}})

            return Promise.resolve().then ->
                expect(mocks.confirm.notify).to.have.been.calledWith("light-error", ERROR_CODES[code])
                expect(form.find("li.checksley-custom").length).to.be.equal(0)

    it "keeps the generic message when the server sends no code", () ->
        elm = createDirective()
        submitForm(elm)

        mocks.auth.register.reject({data: {_error_message: "algo deu errado"}})

        return Promise.resolve().then ->
            expect(mocks.confirm.notify).to.have.been.calledWith("light-error", "COMMON.GENERIC_ERROR")

    it "marks the field errors the server sends", () ->
        elm = createDirective()
        form = submitForm(elm)

        mocks.auth.register.reject({data: {email: ["Este e-mail não é válido"]}})

        return Promise.resolve().then ->
            errors = form.find("li.checksley-custom")
            expect(errors.length).to.be.equal(1)
            expect(errors.text()).to.be.equal("Este e-mail não é válido")
