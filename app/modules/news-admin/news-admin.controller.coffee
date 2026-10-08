###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

# Tela de gestão do carrossel de novidades da home pública.
# Só superusuário: o servidor recusa os demais; aqui só escondemos a tela.

# Códigos que o servidor devolve nos 400 (e 401/403) e têm mensagem em NEWS_ADMIN.ERRORS
KNOWN_ERROR_CODES = [
    "forbidden", "image_required", "invalid_image", "image_too_large",
    "title_required", "title_too_long", "description_too_long",
    "order_negative", "order_invalid", "slide_not_found", "empty_bulk"
]

# Lightbox de edição do slide (markup em news-admin.jade)
EDIT_LIGHTBOX = ".lightbox-news-slide-edit"

class NewsAdminController
    @.$inject = [
        "$tgResources",
        "tgCurrentUserService",
        "tgErrorHandlingService",
        "$tgConfirm",
        "$translate",
        "lightboxService"
    ]

    constructor: (@rs, @currentUserService, @errorHandlingService, @confirm, @translate, @lightboxService) ->
        @.isAdmin = @currentUserService.getUser()?.get("is_superuser") == true
        @.maxImageSize = @rs.news.NEWS_SLIDE_MAX_IMAGE_SIZE
        @.titleMaxLength = 255
        @.descriptionMaxLength = 500

        @.slides = []
        @.loading = false
        @.loadError = false
        @.listError = null
        @.saving = false
        @.formError = null
        @.editing = null
        @.editError = null
        @.resetForm()

        if not @.isAdmin
            @errorHandlingService.permissionDenied()
            return

        @.loadSlides()

    # Retorno visual das ações concluídas: a notificação padrão do Taiga, como nas telas de admin
    notifySuccess: ->
        @confirm.notify("success")

    resetForm: ->
        @.form = {title: "", description: "", order: null, file: null, fileName: null}

    loadSlides: ->
        @.loading = true
        @.loadError = false
        return @rs.news.list()
            .then (slides) =>
                @.slides = slides
                @.loading = false
            .catch =>
                @.loadError = true
                @.loading = false

    selectImage: (files) ->
        @.form.file = files?[0] or null
        @.form.fileName = @.form.file?.name or null
        @.formError = @.imageSizeError(@.form.file)

    selectEditImage: (files) ->
        return if not @.editing
        @.editing.file = files?[0] or null
        @.editing.fileName = @.editing.file?.name or null
        @.editError = @.imageSizeError(@.editing.file)

    imageSizeError: (file) ->
        if file and file.size > @.maxImageSize
            return @.errorMessage({data: {image: ["image_too_large"]}})
        return null

    create: ->
        return if @.saving
        if not @.form.file
            @.formError = @translate.instant("NEWS_ADMIN.ERRORS.IMAGE_REQUIRED")
            return
        if not @.form.title?.trim()
            @.formError = @translate.instant("NEWS_ADMIN.ERRORS.TITLE_REQUIRED")
            return

        data = {title: @.form.title.trim(), description: @.form.description or ""}
        data.order = @.form.order if @.form.order? and @.form.order != ""

        @.saving = true
        @.formError = null
        return @rs.news.create(data, @.form.file)
            .then =>
                @.saving = false
                @.resetForm()
                @.notifySuccess()
                @.loadSlides()
            .catch (response) =>
                @.saving = false
                @.formError = @.errorMessage(response)

    # Abre o modal; qualquer fechamento (X, Esc, Cancelar, salvar) passa pelo
    # lightboxService.close, que chama o onClose e limpa o estado de edição
    startEdit: (slide) ->
        @.editError = null
        @.editing = {
            id: slide.id
            title: slide.title
            description: slide.description
            order: slide.order
            file: null
            fileName: null
        }
        @lightboxService.open EDIT_LIGHTBOX, =>
            @.editing = null
            @.editError = null

    cancelEdit: ->
        @lightboxService.close(EDIT_LIGHTBOX)

    saveEdit: ->
        return if @.saving or not @.editing
        editing = @.editing
        data = {title: editing.title, description: editing.description or "", order: editing.order}

        @.saving = true
        @.editError = null
        promise = @rs.news.update(editing.id, data)
        if editing.file
            promise = promise.then => @rs.news.changeImage(editing.id, editing.file)

        return promise
            .then =>
                @.saving = false
                @lightboxService.close(EDIT_LIGHTBOX)
                @.notifySuccess()
                @.loadSlides()
            .catch (response) =>
                @.saving = false
                @.editError = @.errorMessage(response)

    toggleActive: (slide) ->
        return if @.saving
        @.saving = true
        @.listError = null
        return @rs.news.update(slide.id, {is_active: !slide.is_active})
            .then (updated) =>
                @.saving = false
                slide.is_active = updated.is_active
                @.notifySuccess()
            .catch (response) =>
                @.saving = false
                @.listError = @.errorMessage(response)

    remove: (slide) ->
        title = @translate.instant("NEWS_ADMIN.DELETE_TITLE")
        return @confirm.askOnDelete(title, slide.title).then (askResponse) =>
            @rs.news.remove(slide.id)
                .then =>
                    askResponse.finish()
                    @.notifySuccess()
                    @.loadSlides()
                .catch (response) =>
                    askResponse.finish(false)
                    @.listError = @.errorMessage(response)

    moveUp: (index) ->
        return if index <= 0
        @.swap(index, index - 1)

    moveDown: (index) ->
        return if index >= @.slides.length - 1
        @.swap(index, index + 1)

    swap: (from, to) ->
        return if @.saving
        [@.slides[from], @.slides[to]] = [@.slides[to], @.slides[from]]
        @.reorder()

    # Uma única chamada com a lista inteira, na ordem em que está na tela
    reorder: ->
        items = _.map(@.slides, (slide, index) -> {slide_id: slide.id, order: index})
        @.saving = true
        @.listError = null
        return @rs.news.bulkUpdateOrder(items)
            .then =>
                @.saving = false
                slide.order = index for slide, index in @.slides
                @.notifySuccess()
            .catch (response) =>
                @.saving = false
                @.listError = @.errorMessage(response)
                @.loadSlides()

    # Código do servidor (400 por campo ou {code}) vira mensagem traduzida; sem código, mensagem genérica
    errorMessage: (response) ->
        code = null
        data = response?.data
        if response?.status in [401, 403]
            code = "forbidden"
        else if _.isPlainObject(data)
            if _.isString(data.code)
                code = data.code
            else
                for field, errors of data when _.isArray(errors) and _.isString(errors[0])
                    code = errors[0]
                    break

        code = "generic" if code not in KNOWN_ERROR_CODES
        return @translate.instant("NEWS_ADMIN.ERRORS.#{code.toUpperCase()}")

angular.module("taigaNewsAdmin").controller("NewsAdmin", NewsAdminController)
