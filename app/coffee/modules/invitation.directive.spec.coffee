###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "tgInvitation", () ->
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
            getInvitation: sinon.stub().promise()
            acceptInvitiationWithNewUser: sinon.stub().promise()
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
        }
        provide.value "$tgLocation", mocks.location

    _mockTgConfig = () ->
        mocks.config = {
            get: sinon.stub()
        }
        provide.value "$tgConfig", mocks.config

    _mockRouteParams = () ->
        provide.value "$routeParams", {token: "invitation-token"}

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

    beforeEach ->
        module "templates"
        module "taigaAuth"

        _mocks()

        inject ($rootScope, $compile, $templateCache) ->
            scope = $rootScope.$new()
            compile = $compile
            # o partial real da página de convite, para o teste falhar se a tela mudar
            template = $templateCache.get("auth/invitation.html")

    it "offers a link to the login screen", () ->
        elm = createDirective()

        link = elm.find(".go-to-login")
        expect(link.length).to.be.equal(1)
        expect(link.attr("tg-nav")).to.be.equal("login")

    it "sends the invitation project as the destination of the login", () ->
        elm = createDirective()

        mocks.navUrls.resolve.withArgs("project", {project: "project-slug"}).returns("/project/project-slug")
        mocks.auth.getInvitation.resolve({project_slug: "project-slug", project_name: "Projeto"})

        # o convite chega de forma assíncrona: o link só reflete o destino no digest seguinte
        return Promise.resolve().then ->
            scope.$digest()
            params = JSON.parse(elm.find(".go-to-login").attr("tg-nav-get-params"))
            expect(params.next).to.be.equal("/project/project-slug")

    it "does not send a broken destination before the invitation loads", () ->
        elm = createDirective()

        params = elm.find(".go-to-login").attr("tg-nav-get-params")
        expect(params).to.not.contain("undefined")
        expect(JSON.parse(params).next).to.be.equal("")

    it "does not ask for username and password", () ->
        elm = createDirective()

        loginBlock = elm.find(".login-form")
        expect(loginBlock.find("input[name=username]").length).to.be.equal(0)
        expect(loginBlock.find("input[name=password]").length).to.be.equal(0)
        expect(loginBlock.find(".g-recaptcha").length).to.be.equal(0)

    it "keeps the register form", () ->
        elm = createDirective()

        expect(elm.find("form.register-form").length).to.be.equal(1)

    # preenche o formulário com dados válidos para o envio chegar ao servidor
    submitRegisterForm = (elm) ->
        form = elm.find("form.register-form")
        form.find("input[name=username]").val("private_user")
        form.find("input[name=full_name]").val("Private User")
        form.find("input[name=email]").val("private_user@email.com")
        form.find("input[name=password]").val("password")
        form.trigger("submit")

        return form

    it "translates the code the server sends when the email is not the invited one", () ->
        elm = createDirective()
        submitRegisterForm(elm)

        expect(mocks.auth.acceptInvitiationWithNewUser).to.have.been.called
        mocks.auth.acceptInvitiationWithNewUser.reject({data: {code: "invitation_email_mismatch"}})

        return Promise.resolve().then ->
            expect(mocks.confirm.notify).to.have.been.calledWith("light-error",
                                                                "INVITATION_LOGIN_FORM.EMAIL_MISMATCH")

    it "translates the code the server sends when the invitation is not valid", () ->
        elm = createDirective()
        submitRegisterForm(elm)

        mocks.auth.acceptInvitiationWithNewUser.reject({data: {code: "invitation_not_valid"}})

        return Promise.resolve().then ->
            expect(mocks.confirm.notify).to.have.been.calledWith("light-error",
                                                                "INVITATION_LOGIN_FORM.NOT_VALID")

    it "does not mark a form field when the server sends only a code", () ->
        elm = createDirective()
        form = submitRegisterForm(elm)

        mocks.auth.acceptInvitiationWithNewUser.reject({data: {code: "invitation_email_mismatch"}})

        return Promise.resolve().then ->
            expect(form.find("li.checksley-custom").length).to.be.equal(0)

    it "marks the field errors the server sends", () ->
        elm = createDirective()
        form = submitRegisterForm(elm)

        mocks.auth.acceptInvitiationWithNewUser.reject({data: {email: ["Este e-mail já existe"]}})

        return Promise.resolve().then ->
            errors = form.find("li.checksley-custom")
            expect(errors.length).to.be.equal(1)
            expect(errors.text()).to.be.equal("Este e-mail já existe")

    it "keeps the generic message when the server sends no code", () ->
        elm = createDirective()
        submitRegisterForm(elm)

        mocks.auth.acceptInvitiationWithNewUser.reject({data: {_error_message: "algo deu errado"}})

        return Promise.resolve().then ->
            expect(mocks.confirm.notify).to.have.been.calledWith("light-error", "COMMON.GENERIC_ERROR")

    REGISTER_CODES = {
        "username_already_in_use": "REGISTER_FORM.USERNAME_ALREADY_IN_USE"
        "email_already_in_use": "REGISTER_FORM.EMAIL_ALREADY_IN_USE"
        "user_creation_failed": "REGISTER_FORM.USER_CREATION_FAILED"
        "terms_not_accepted": "REGISTER_FORM.TERMS_NOT_ACCEPTED"
        "invalid_registration_type": "REGISTER_FORM.INVALID_REGISTRATION_TYPE"
    }

    Object.keys(REGISTER_CODES).forEach (code) ->
        it "translates the register code #{code}", () ->
            elm = createDirective()
            form = submitRegisterForm(elm)

            mocks.auth.acceptInvitiationWithNewUser.reject({data: {code: code}})

            return Promise.resolve().then ->
                expect(mocks.confirm.notify).to.have.been.calledWith("light-error", REGISTER_CODES[code])
                expect(form.find("li.checksley-custom").length).to.be.equal(0)
