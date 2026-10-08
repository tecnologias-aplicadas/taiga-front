###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

taiga = @.taiga
debounce = @.taiga.debounce

module = angular.module("taigaAuth", ["taigaResources"])

class LoginPage
    @.$inject = [
        'tgCurrentUserService',
        '$location',
        '$tgNavUrls',
        '$routeParams',
        '$tgAuth'
    ]

    constructor: (currentUserService, $location, $navUrls, $routeParams, $auth) ->
        if currentUserService.isAuthenticated()
            if not $routeParams['force_login']
                url = $navUrls.resolve("home")
                if $routeParams['next']
                    url = decodeURIComponent($routeParams['next'])
                    $location.search('next', null)

                if $routeParams['unauthorized']
                    $auth.clear()
                    $auth.removeToken()
                else
                    $location.url(url)


module.controller('LoginPage', LoginPage)

#############################################################################
## Authentication Service
#############################################################################

# Idioma do último usuário que entrou neste navegador: vale nas telas sem
# login (home, login, guia) até outro usuário entrar com idioma diferente.
LAST_USER_LANG_KEY = "lastUserLang"

# Usuário autenticado usa o próprio idioma (ou o padrão da instância); sem
# usuário, o do último que entrou neste navegador (ou o padrão).
taiga.resolveLanguage = (user, lastUserLang, defaultLanguage) ->
    if user
        return user.lang || defaultLanguage || "en"
    return lastUserLang || defaultLanguage || "en"

# Lê a chave como o $tgStorage grava (JSON em localStorage); usável no bootstrap
taiga.lastUserLangFromStorage = ->
    try
        return JSON.parse(localStorage.getItem(LAST_USER_LANG_KEY))
    catch
        return null

class AuthService extends taiga.Service
    @.$inject = ["$rootScope",
                 "$tgStorage",
                 "$tgModel",
                 "$tgResources",
                 "$tgHttp",
                 "$tgUrls",
                 "$tgConfig",
                 "$tgUserPilot",
                 "$translate",
                 "tgCurrentUserService",
                 "tgThemeService",
                 "$tgAnalytics"]

    constructor: (@rootscope, @storage, @model, @rs, @http, @urls, @config, @userpilot, @translate, @currentUserService,
                  @themeService, @analytics) ->
        super()

        userModel = @.getUser()
        @._currentTheme = @._getUserTheme()

        @.setUserdata(userModel)

    setUserdata: (userModel) ->
        if userModel
            @.userData = Immutable.fromJS(userModel.getAttrs())
            @currentUserService.setUser(@.userData)
        else
            @.userData = null
        @analytics.setUserId()

    _getUserTheme: ->
        compiledThemes = window._taigaAvailableThemes
        defaultTheme = @config.get("defaultTheme") || "taiga"

        if !_.includes(@config.get("themes"), @rootscope.user?.theme) || !compiledThemes.includes(@rootscope.user?.theme)
            return defaultTheme

        return @rootscope.user?.theme

    _setTheme: ->
        newTheme = @._getUserTheme()

        if @._currentTheme != newTheme
            @._currentTheme = newTheme
            @themeService.use(@._currentTheme)

    _setLocales: ->
        user = @rootscope.user
        if user?.lang
            @storage.set(LAST_USER_LANG_KEY, user.lang)

        lang = taiga.resolveLanguage(user, @storage.get(LAST_USER_LANG_KEY), @config.get("defaultLanguage"))
        @translate.preferredLanguage(lang)  # Needed for calls to the api in the correct language
        @translate.use(lang)                # Needed for change the interface in runtime

    getUser: ->
        if @rootscope.user
            return @rootscope.user

        userData = @storage.get("userInfo")

        if userData
            user = @model.make_model("users", userData)
            @rootscope.user = user
            @._setLocales()

            @._setTheme()

            return user
        else
            @._setTheme()

        return null

    setUser: (user) ->
        @rootscope.auth = user
        @storage.set("userInfo", user.getAttrs())
        @rootscope.user = user

        @.setUserdata(user)

        @._setLocales()
        @._setTheme()

    clear: ->
        @rootscope.auth = null
        @rootscope.user = null
        @storage.remove("userInfo")

    setRefreshToken: (token) ->
        @storage.set("refresh", token)

    getRefreshToken: ->
        return @storage.get("refresh")

    setToken: (token) ->
        @storage.set("token", token)

    getToken: ->
        return @storage.get("token")

    removeToken: ->
        @storage.remove("token")
        @storage.remove("refresh")

    isAuthenticated: ->
        if @.getUser() != null
            return true
        return false

    ## Http interface
    refresh: () ->
        url = @urls.resolve("user-me")

        return @http.get(url).then (data, status) =>
            user = data.data
            user.token = @.getUser().auth_token

            user = @model.make_model("users", user)

            @.setUser(user)
            @rootscope.$broadcast("auth:refresh", user)
            return user

    login: (data, type, endpoint) ->
        url = @urls.resolve(endpoint or "auth")

        data = _.clone(data, false)
        data.type = if type then type else "normal"

        @.removeToken()

        return @http.post(url, data).then (data, status) =>
            user = @model.make_model("users", data.data)
            @.setToken(user.auth_token)
            @.setRefreshToken(user.refresh)
            @.setUser(user)
            @rootscope.$broadcast("auth:login", user)
            return user

    logout: ->
        @.removeToken()
        @.clear()
        @currentUserService.removeUser()

        @._setTheme()
        @._setLocales()
        @rootscope.$broadcast("auth:logout")
        @analytics.setUserId()

    register: (data, type, existing) ->
        url = @urls.resolve("auth-register")

        data = _.clone(data, false)
        data.type = if type then type else "public"
        if type == "private"
            data.existing = if existing then existing else false

        @.removeToken()

        return @http.post(url, data).then (response) =>
            user = @model.make_model("users", response.data)
            @.setToken(user.auth_token)
            @.setUser(user)
            @rootscope.$broadcast("auth:register", user)
            return user

    getInvitation: (token) ->
        return @rs.invitations.get(token)

    acceptInvitiationWithNewUser: (data) ->
        return @.register(data, "private", false)

    forgotPassword: (data) ->
        url = @urls.resolve("users-password-recovery")
        data = _.clone(data, false)
        @.removeToken()
        return @http.post(url, data)

    changePasswordFromRecovery: (data) ->
        url = @urls.resolve("users-change-password-from-recovery")
        data = _.clone(data, false)
        @.removeToken()
        return @http.post(url, data)

    changeEmail: (data) ->
        url = @urls.resolve("users-change-email")
        data = _.clone(data, false)
        return @http.post(url, data)

    cancelAccount: (data) ->
        url = @urls.resolve("users-cancel-account")
        data = _.clone(data, false)
        return @http.post(url, data)

    exportProfile: () ->
        url = @urls.resolve("users-export")
        return @http.post(url)

    sendVerificationEmail: () ->
        url = @urls.resolve("user-send-verification-email")
        return @http.post(url)

module.service("$tgAuth", AuthService)


#############################################################################
## Login Directive
#############################################################################

# Directive that manages the visualization of public register
# message/link on login page.

PublicRegisterMessageDirective = ($config, $navUrls, $routeParams, templates) ->
    template = templates.get("auth/login-text.html", true)

    templateFn = ->
        publicRegisterEnabled = $config.get("publicRegisterEnabled")
        if not publicRegisterEnabled
            return ""

        url = $navUrls.resolve("register")

        if $routeParams['force_next']
            nextUrl = encodeURIComponent($routeParams['force_next'])
            url += "?next=#{nextUrl}"

        return template({url:url})

    return {
        restrict: "AE"
        scope: {}
        template: templateFn
    }

module.directive("tgPublicRegisterMessage", ["$tgConfig", "$tgNavUrls", "$routeParams",
                                             "$tgTemplate", PublicRegisterMessageDirective])


# O servidor devolve código, não texto: o texto mostrado é destas tabelas.
# Erros do login com usuário e senha.
LOGIN_ERROR_TEXTS = {
    "invalid_credentials": "LOGIN_COMMON.INVALID_CREDENTIALS"
    "undefined_credentials": "LOGIN_COMMON.UNDEFINED_CREDENTIALS"
    "invalid_recaptcha": "LOGIN_COMMON.INVALID_RECAPTCHA"
}

# Erros do convite, tanto no aceite junto com o login quanto no registro por convite.
INVITATION_ERROR_TEXTS = {
    "invitation_email_mismatch": "INVITATION_LOGIN_FORM.EMAIL_MISMATCH"
    "invitation_not_valid": "INVITATION_LOGIN_FORM.NOT_VALID"
    "already_project_member": "INVITATION_LOGIN_FORM.ALREADY_MEMBER"
    "user_does_not_exist": "INVITATION_LOGIN_FORM.USER_NOT_FOUND"
}

# Erros dos dois formulários de registro, o público e o do convite.
REGISTER_ERROR_TEXTS = {
    "username_already_in_use": "REGISTER_FORM.USERNAME_ALREADY_IN_USE"
    "email_already_in_use": "REGISTER_FORM.EMAIL_ALREADY_IN_USE"
    "user_creation_failed": "REGISTER_FORM.USER_CREATION_FAILED"
    "public_register_disabled": "REGISTER_FORM.PUBLIC_REGISTER_DISABLED"
    "terms_not_accepted": "REGISTER_FORM.TERMS_NOT_ACCEPTED"
    "invalid_registration_type": "REGISTER_FORM.INVALID_REGISTRATION_TYPE"
}


LoginDirective = ($auth, $confirm, $location, $config, $routeParams, $navUrls, $events, $translate, $window, $analytics, $timeout, $rootScope) ->
    link = ($scope, $el, $attrs) ->
        $scope.defaultLoginEnabled = $config.get("defaultLoginEnabled", true)
        $scope.reCaptchaSiteKey = $config.get("reCaptchaSiteKey")

        # ignore next param if is the login or discover page
        if $routeParams['next'] and $routeParams['next']  != $navUrls.resolve("login") and !$routeParams['next'].startsWith("%2Fdiscover")
            $scope.nextUrl = decodeURIComponent($routeParams['next'])
        else
            $scope.nextUrl = $navUrls.resolve("home")

        if $routeParams['force_next']
            $scope.nextUrl = decodeURIComponent($routeParams['force_next'])

        onSuccess = (response) ->
            $events.setupConnection()
            $analytics.trackEvent("auth", "login", "user login", 1)

            if $scope.nextUrl.indexOf('http') == 0
                $window.location.href = $scope.nextUrl
            else
                $location.url($scope.nextUrl)

        onError = (response) ->
            # o convite enviado junto com o login falha pelos códigos do convite
            code = response.data?.code
            errorKey = LOGIN_ERROR_TEXTS[code] or INVITATION_ERROR_TEXTS[code]

            if errorKey
                text = $translate.instant(errorKey, {adminTeam: $rootScope.adminTeam})
                $confirm.notify("light-error", text)
            else if response.data?._error_message
                text = $translate.instant("COMMON.GENERIC_ERROR", {error: response.data._error_message})
                $confirm.notify("light-error", text)
            else if response.data?.detail
                $confirm.notify("light-error", response.data.detail)

        $scope.onKeyUp = (event) ->
            target = angular.element(event.currentTarget)
            value = target.val()
            $scope.iscapsLockActivated = false
            if value != value.toLowerCase()
                $scope.iscapsLockActivated = true

        # reCAPTCHA explicit render — each tab renders its widget only when visible
        corporateWidgetId = null
        externalWidgetId  = null
        recaptchaReady    = false
        siteKey           = $scope.reCaptchaSiteKey

        renderCorporateRecaptcha = ->
            return if corporateWidgetId?
            return if not recaptchaReady
            container = $el.find("form.login-form-corporate .g-recaptcha")[0]
            return if not container
            corporateWidgetId = $window.grecaptcha.render(container, {
                sitekey: siteKey,
                callback: -> updateCorporateSubmit(),
                'expired-callback': -> updateCorporateSubmit()
            })

        renderExternalRecaptcha = ->
            return if externalWidgetId?
            return if not recaptchaReady
            container = $el.find("form.login-form-external .g-recaptcha")[0]
            return if not container
            externalWidgetId = $window.grecaptcha.render(container, {
                sitekey: siteKey,
                callback: -> updateExternalSubmit(),
                'expired-callback': -> updateExternalSubmit()
            })

        $window.onRecaptchaLoad = ->
            recaptchaReady = true
            renderCorporateRecaptcha()

        activateTab = (tab) ->
            $el.find(".login-tab").removeClass("active")
            $el.find(".login-form-corporate, .login-form-external").hide()
            if tab is "corporate"
                $el.find(".js-tab-corporate").addClass("active")
                $el.find(".login-form-corporate").show()
                renderCorporateRecaptcha()
            else
                $el.find(".js-tab-external").addClass("active")
                $el.find(".login-form-external").show()
                renderExternalRecaptcha()

        # Inicia na aba corporativa
        activateTab("corporate")

        $el.on "click", ".js-tab-corporate", ->
            activateTab("corporate")

        $el.on "click", ".js-tab-external", ->
            activateTab("external")

        formCorporate = $el.find("form.login-form-corporate").checksley()
        formExternal  = $el.find("form.login-form-external").checksley()

        getRecaptchaResponse = (widgetId) ->
            try
                return $window.grecaptcha?.getResponse(widgetId) or ''
            catch
                return ''

        setLoading = (form, loading) ->
            btn = form.find("button[type=submit]")
            if loading
                btn.addClass("is-loading").prop("disabled", true)
            else
                btn.removeClass("is-loading")
                updateCorporateSubmit() if form.hasClass("login-form-corporate")
                updateExternalSubmit()  if form.hasClass("login-form-external")

        captchaRequired = siteKey and $config.get("environment") isnt "local"

        updateCorporateSubmit = ->
            username  = $el.find("form.login-form-corporate input[name=username]").val()
            password  = $el.find("form.login-form-corporate input[name=password]").val()
            captchaOk = if captchaRequired then !!getRecaptchaResponse(corporateWidgetId) else true
            hasAt     = username.indexOf("@") >= 0
            canSubmit = username.trim().length > 0 and password.trim().length > 0 and captchaOk and not hasAt
            $el.find("form.login-form-corporate button[type=submit]").prop("disabled", not canSubmit)

        updateExternalSubmit = ->
            username  = $el.find("form.login-form-external input[name=username]").val()
            password  = $el.find("form.login-form-external input[name=password]").val()
            captchaOk = if captchaRequired then !!getRecaptchaResponse(externalWidgetId) else true
            canSubmit = username.trim().length > 0 and password.trim().length > 0 and captchaOk
            $el.find("form.login-form-external button[type=submit]").prop("disabled", not canSubmit)

        corporateUsernameInput = $el.find("form.login-form-corporate input[name=username]")
        corporateUsernameError = $el.find("form.login-form-corporate .username-at-error")

        corporateUsernameInput.on "input", ->
            hasAt = $(@).val().indexOf("@") >= 0
            corporateUsernameError.toggle(hasAt)
            updateCorporateSubmit()

        $el.find("form.login-form-corporate input[name=password]").on "input", -> updateCorporateSubmit()

        submitCorporate = debounce 2000, (event) =>
            event.preventDefault()
            return if not formCorporate.validate()

            form = $el.find("form.login-form-corporate")
            username = form.find("input[name=username]").val()

            if username.indexOf("@") >= 0
                corporateUsernameError.show()
                return

            setLoading(form, true)

            vpnWarning = $timeout ->
                $confirm.notify("light-error", $translate.instant("LOGIN_COMMON.LDAP_TIMEOUT"))
                setLoading(form, false)
            , 10000

            data = {
                "username": username,
                "password": form.find("input[name=password]").val(),
                "g-recaptcha-response": getRecaptchaResponse(corporateWidgetId)
            }
            promise = $auth.login(data, "normal", "auth-corporate")
            promise.then(onSuccess, onError).finally ->
                $timeout.cancel(vpnWarning)
                setLoading(form, false)

        externalUsernameInput = $el.find("form.login-form-external input[name=username]")
        externalUsernameError = $el.find("form.login-form-external .username-at-error")

        externalUsernameInput.on "input", ->
            updateExternalSubmit()

        $el.find("form.login-form-external input[name=password]").on "input", -> updateExternalSubmit()

        submitExternal = debounce 2000, (event) =>
            event.preventDefault()
            return if not formExternal.validate()

            form = $el.find("form.login-form-external")
            username = form.find("input[name=username]").val()

            setLoading(form, true)

            data = {
                "username": username,
                "password": form.find("input[name=password]").val(),
                "g-recaptcha-response": getRecaptchaResponse(externalWidgetId)
            }
            promise = $auth.login(data, "normal", "auth-external")
            promise.then(onSuccess, onError).finally -> setLoading(form, false)

        $el.find("form.login-form-corporate").on "submit", submitCorporate
        $el.find("form.login-form-external").on "submit", submitExternal

        updateCorporateSubmit()
        updateExternalSubmit()

        $el.find(".password-toggle")
            .on "mousedown touchstart", (e) ->
                e.preventDefault()
                $(@).siblings("input[name=password]").attr("type", "text")
            .on "mouseup touchend mouseleave", ->
                $(@).siblings("input[name=password]").attr("type", "password")

        window.prerenderReady = true

        $scope.$on "$destroy", ->
            $el.off()
            $window.onRecaptchaLoad = null

    return {link:link}

module.directive("tgLogin", ["$tgAuth", "$tgConfirm", "$tgLocation", "$tgConfig", "$routeParams",
                             "$tgNavUrls", "$tgEvents", "$translate", "$window", "$tgAnalytics", "$timeout", "$rootScope", LoginDirective])


#############################################################################
## Register Directive
#############################################################################

RegisterDirective = ($auth, $confirm, $location, $navUrls, $config, $routeParams, $analytics, $translate, $window) ->
    link = ($scope, $el, $attrs) ->
        if not $config.get("publicRegisterEnabled")
            $location.path($navUrls.resolve("not-found"))
            $location.replace()

        $scope.data = {}
        form = $el.find("form").checksley({onlyOneErrorElement: true})

        if $routeParams['next'] and $routeParams['next'] != $navUrls.resolve("login")
            $scope.nextUrl = decodeURIComponent($routeParams['next'])
        else
            $scope.nextUrl = $navUrls.resolve("home")

        onSuccessSubmit = (response) ->
            $analytics.trackEvent("auth", "register", "user registration", 1)

            if $scope.nextUrl.indexOf('http') == 0
                $window.location.href = $scope.nextUrl
            else
                $location.url($scope.nextUrl)

        onErrorSubmit = (response) ->
            errorKey = REGISTER_ERROR_TEXTS[response.data?.code]

            # com código não há campo do formulário a marcar: a mensagem é daqui
            if errorKey
                text = $translate.instant(errorKey)
                $confirm.notify("light-error", text)
            else
                if response.data?._error_message
                    text = $translate.instant("COMMON.GENERIC_ERROR", {error: response.data._error_message})
                    $confirm.notify("light-error", text)

                form.setErrors(response.data)

        submit = debounce 2000, (event) =>
            event.preventDefault()

            if not form.validate()
                return

            promise = $auth.register($scope.data)
            promise.then(onSuccessSubmit, onErrorSubmit)

        $el.on "submit", "form", submit

        $scope.$on "$destroy", ->
            $el.off()

        window.prerenderReady = true

    return {link:link}

module.directive("tgRegister", ["$tgAuth", "$tgConfirm", "$tgLocation", "$tgNavUrls", "$tgConfig",
                                "$routeParams", "$tgAnalytics", "$translate", "$window", RegisterDirective])


#############################################################################
## Register Options Directive
#############################################################################

RegisterOptionsDirective = () ->
    return { }

module.directive("tgRegisterOptions", [RegisterOptionsDirective])


#############################################################################
## Forgot Password Directive
#############################################################################

ForgotPasswordDirective = ($auth, $confirm, $location, $navUrls, $translate) ->
    link = ($scope, $el, $attrs) ->
        $scope.data = {}
        form = $el.find("form").checksley()

        onSuccessSubmit = (response) ->
            $location.path($navUrls.resolve("login"))

            title = $translate.instant("FORGOT_PASSWORD_FORM.SUCCESS_TITLE")
            message = $translate.instant("FORGOT_PASSWORD_FORM.SUCCESS_TEXT")

            $confirm.success(title, message)

        onErrorSubmit = (response) ->
            if response.data?.code == "corporate_user"
                $scope.corporateWarning = true
            else
                text = $translate.instant("FORGOT_PASSWORD_FORM.ERROR")
                $confirm.notify("light-error", text)

        submit = debounce 2000, (event) =>
            event.preventDefault()
            $scope.corporateWarning = false

            if not form.validate()
                return

            promise = $auth.forgotPassword($scope.data)
            promise.then(onSuccessSubmit, onErrorSubmit)

        $el.on "submit", "form", submit

        $scope.$on "$destroy", ->
            $el.off()

        window.prerenderReady = true

    return {link:link}

module.directive("tgForgotPassword", ["$tgAuth", "$tgConfirm", "$tgLocation", "$tgNavUrls", "$translate",
                                      ForgotPasswordDirective])


#############################################################################
## Change Password from Recovery Directive
#############################################################################

ChangePasswordFromRecoveryDirective = ($auth, $confirm, $location, $params, $navUrls, $translate) ->
    link = ($scope, $el, $attrs) ->
        $scope.data = {}

        if $params.token?
            $scope.tokenInParams = true
            $scope.data.token = $params.token
        else
            $location.path($navUrls.resolve("login"))

            text = ''
            text = response.data.token.map((message) ->
                return "#{text} #{message}"
            )
            $confirm.notify("light-error", text)

        form = $el.find("form").checksley()

        onSuccessSubmit = (response) ->
            $location.path($navUrls.resolve("login"))

            text = $translate.instant("CHANGE_PASSWORD_RECOVERY_FORM.SUCCESS")
            $confirm.success(text)

        onErrorSubmit = (response) ->
            text = ''
            text = response.data.password.map((message) ->
                return "#{text} #{message}"
            )
            $confirm.notify("light-error", text)

        submit = debounce 2000, (event) =>
            event.preventDefault()

            if not form.validate()
                return

            promise = $auth.changePasswordFromRecovery($scope.data)
            promise.then(onSuccessSubmit, onErrorSubmit)

        $el.on "submit", "form", submit

        $scope.$on "$destroy", ->
            $el.off()

    return {link:link}

module.directive("tgChangePasswordFromRecovery", ["$tgAuth", "$tgConfirm", "$tgLocation", "$routeParams",
                                                  "$tgNavUrls", "$translate",
                                                  ChangePasswordFromRecoveryDirective])


#############################################################################
## Invitation
#############################################################################

InvitationDirective = ($auth, $confirm, $location, $config, $params, $navUrls, $analytics, $translate) ->
    link = ($scope, $el, $attrs) ->
        token = $params.token

        promise = $auth.getInvitation(token)
        promise.then (invitation) ->
            $scope.invitation = invitation
            $scope.publicRegisterEnabled = $config.get("publicRegisterEnabled")
            # destino do link para o login: o projeto do convite. Enquanto o convite não chega o
            # endereço fica vazio e a tela de login manda para a home, como faz sem destino nenhum.
            $scope.invitationProjectUrl = $navUrls.resolve("project", {project: invitation.project_slug})

        promise.then null, (response) ->
            $location.path($navUrls.resolve("login"))

            text = $translate.instant("INVITATION_LOGIN_FORM.NOT_FOUND")
            $confirm.notify("light-error", text)

        # Register form
        $scope.dataRegister = {token: token}
        registerForm = $el.find("form.register-form").checksley({onlyOneErrorElement: true})

        onSuccessSubmitRegister = (response) ->
            $analytics.trackEvent("auth", "invitationAccept", "invitation accept with new user", 1)

            $location.path($navUrls.resolve("project", {project: $scope.invitation.project_slug}))
            text = $translate.instant("INVITATION_LOGIN_FORM.SUCCESS", {
                "project_name": $scope.invitation.project_name
            })
            $confirm.notify("success", text)

        onErrorSubmitRegister = (response) ->
            # o servidor devolve código para o que não é erro de campo: a mensagem é daqui,
            # e não há campo do formulário para marcar
            code = response.data?.code
            errorKey = INVITATION_ERROR_TEXTS[code] or REGISTER_ERROR_TEXTS[code]

            if errorKey
                text = $translate.instant(errorKey)
                $confirm.notify("light-error", text)
            else
                if response.data?._error_message
                    text = $translate.instant("COMMON.GENERIC_ERROR", {error: response.data._error_message})
                    $confirm.notify("light-error", text)

                registerForm.setErrors(response.data)

        submitRegister = debounce 2000, (event) =>
            event.preventDefault()

            if not registerForm.validate()
                return

            promise = $auth.acceptInvitiationWithNewUser($scope.dataRegister)
            promise.then(onSuccessSubmitRegister, onErrorSubmitRegister)

        $el.on "submit", "form.register-form", submitRegister
        $el.on "click", ".button-register", submitRegister

        $scope.$on "$destroy", ->
            $el.off()

    return {link:link}

module.directive("tgInvitation", ["$tgAuth", "$tgConfirm", "$tgLocation", "$tgConfig", "$routeParams",
                                  "$tgNavUrls", "$tgAnalytics", "$translate", InvitationDirective])


#############################################################################
## Verify Email
#############################################################################

VerifyEmailDirective = ($repo, $model, $auth, $confirm, $location, $params, $navUrls, $translate) ->
    link = ($scope, $el, $attrs) ->
        $scope.data = {}
        $scope.data.email_token = $params.email_token
        form = $el.find("form").checksley()

        onSuccessSubmit = (response) ->
            if $auth.isAuthenticated()
                $repo.queryOne("users", $auth.getUser().id).then (data) =>
                    $auth.setUser(data)
                $location.url($navUrls.resolve("home"))
            else
                $location.url($navUrls.resolve("login"))

            text = $translate.instant("VERIFY_EMAIL_FORM.SUCCESS")
            $confirm.success(text)

        onErrorSubmit = (response) ->
            text = $translate.instant("COMMON.GENERIC_ERROR", {error: response.data._error_message})

            $confirm.notify("light-error", text)

        submit = ->
            if not form.validate()
                return

            promise = $auth.changeEmail($scope.data)
            promise.then(onSuccessSubmit, onErrorSubmit)

        $el.on "submit", (event) ->
            event.preventDefault()
            submit()

        $el.on "click", "a.ng-submit-form", (event) ->
            event.preventDefault()
            submit()

        $scope.$on "$destroy", ->
            $el.off()

    return {link:link}

module.directive("tgVerifyEmail", ["$tgRepo", "$tgModel", "$tgAuth", "$tgConfirm", "$tgLocation",
                                   "$routeParams", "$tgNavUrls", "$translate", VerifyEmailDirective])


#############################################################################
## Change Email
#############################################################################

ChangeEmailDirective = ($repo, $model, $auth, $confirm, $location, $params, $navUrls, $translate) ->
    link = ($scope, $el, $attrs) ->
        $scope.data = {}
        $scope.data.email_token = $params.email_token
        form = $el.find("form").checksley()

        onSuccessSubmit = (response) ->
            if $auth.isAuthenticated()
                $repo.queryOne("users", $auth.getUser().id).then (data) =>
                    $auth.setUser(data)
                $location.url($navUrls.resolve("home"))
            else
                $location.url($navUrls.resolve("login"))

            text = $translate.instant("CHANGE_EMAIL_FORM.SUCCESS")
            $confirm.success(text)

        onErrorSubmit = (response) ->
            text = $translate.instant("COMMON.GENERIC_ERROR", {error: response.data._error_message})

            $confirm.notify("light-error", text)

        submit = ->
            if not form.validate()
                return

            promise = $auth.changeEmail($scope.data)
            promise.then(onSuccessSubmit, onErrorSubmit)

        $el.on "submit", (event) ->
            event.preventDefault()
            submit()

        $el.on "click", "a.ng-submit-form", (event) ->
            event.preventDefault()
            submit()

        $scope.$on "$destroy", ->
            $el.off()

    return {link:link}

module.directive("tgChangeEmail", ["$tgRepo", "$tgModel", "$tgAuth", "$tgConfirm", "$tgLocation",
                                   "$routeParams", "$tgNavUrls", "$translate", ChangeEmailDirective])


#############################################################################
## Cancel account
#############################################################################

CancelAccountDirective = ($repo, $model, $auth, $confirm, $location, $params, $navUrls) ->
    link = ($scope, $el, $attrs) ->
        $scope.data = {}
        $scope.data.cancel_token = $params.cancel_token
        form = $el.find("form").checksley()

        onSuccessSubmit = (response) ->
            $auth.logout()
            $location.path($navUrls.resolve("home"))

            text = $translate.instant("CANCEL_ACCOUNT.SUCCESS")

            $confirm.success(text)

        onErrorSubmit = (response) ->
            text = $translate.instant("COMMON.GENERIC_ERROR", {error: response.data._error_message})

            $confirm.notify("error", text)

        submit = debounce 2000, (event) =>
            event.preventDefault()

            if not form.validate()
                return

            promise = $auth.cancelAccount($scope.data)
            promise.then(onSuccessSubmit, onErrorSubmit)

        $el.on "submit", "form", submit

        $scope.$on "$destroy", ->
            $el.off()

    return {link:link}

module.directive("tgCancelAccount", ["$tgRepo", "$tgModel", "$tgAuth", "$tgConfirm", "$tgLocation",
                                     "$routeParams","$tgNavUrls", CancelAccountDirective])
