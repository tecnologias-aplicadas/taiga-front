###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "tgWysiwyg", ->
    scope = compile = provide = $q = $rootScope = $sce = null
    mocks = {}

    STORAGE_KEY = "1-1-us"

    _mocks = ->
        module ($provide) ->
            provide = $provide
            provide.value "$translate", {
                instant: sinon.stub().returnsArg(0)
                preferredLanguage: -> "pt-br"
            }
            provide.value "translateFilter", (value) -> value
            provide.value "$tgConfirm", {ask: sinon.stub()}
            mocks.storage = {get: sinon.stub(), set: sinon.stub(), remove: sinon.stub()}
            provide.value "$tgStorage", mocks.storage
            mocks.wysiwygService = {
                refreshAttachmentURLFromMarkdown: sinon.spy (markdown) -> $q.resolve(markdown)
                getMarkdown: (html) -> html
                getHTML: (markdown) -> $sce.trustAsHtml(markdown)
                relativePaths: (html) -> html
                refreshAttachmentURL: (html) -> $q.resolve(html)
            }
            provide.value "tgWysiwygService", mocks.wysiwygService
            provide.value "animationFrame", {add: (callback) -> callback()}
            provide.value "tgLoader", {open: (-> false), onEnd: sinon.stub()}
            provide.value "$tgAnalytics", {trackEvent: sinon.stub()}
            provide.value "$location", {}
            provide.value "tgAttachmentsFullService", {attachments: Immutable.List()}
            mocks.editingTracker = {begin: sinon.stub(), end: sinon.stub()}
            provide.value "tgEditingTracker", mocks.editingTracker
            return null

    # `tg-text-editor` é um custom element sem registro nos testes: vira um elemento
    # simples cujas propriedades (markdown, mode) podem ser lidas
    _compile = (content) ->
        scope.content = content
        scope.project = {id: 1, slug: "projeto", members: []}
        scope.storageKey = STORAGE_KEY
        scope.version = 1
        scope.onSave = sinon.spy (text, cb) ->
            scope.content = text
            cb()
        scope.onCancel = sinon.stub()

        elm = compile("""
            <tg-wysiwyg html-read-mode="true" project="project" version="version"
                        storage-key="storageKey" content="content"
                        on-save="onSave(text, cb)" on-cancel="onCancel()"></tg-wysiwyg>
        """)(scope)
        scope.$apply()
        return elm

    _editor = (elm) -> elm[0].querySelector("tg-text-editor")

    beforeEach ->
        module "templates"
        module "taigaComponents"
        _mocks()

        inject ($compile, _$rootScope_, _$q_, _$sce_) ->
            $rootScope = _$rootScope_
            $q = _$q_
            $sce = _$sce_
            scope = $rootScope.$new()
            compile = $compile

    it "conteúdo inicial cria o editor uma vez e renderiza o texto", ->
        elm = _compile("# Descrição")
        editor = _editor(elm)

        expect(editor).to.exist
        expect(editor.markdown).to.be.equal("# Descrição")
        expect(elm.isolateScope().markdown).to.be.equal("# Descrição")
        expect(elm[0].querySelectorAll("tg-text-editor").length).to.be.equal(1)

    it "conteúdo alterado no servidor fora do modo de edição atualiza o texto e o editor", ->
        elm = _compile("# Descrição")
        isolate = elm.isolateScope()

        scope.content = "# Descrição alterada pela T·IA"
        scope.$apply()

        expect(isolate.markdown).to.be.equal("# Descrição alterada pela T·IA")
        expect(_editor(elm).markdown).to.be.equal("# Descrição alterada pela T·IA")
        expect(elm[0].querySelectorAll("tg-text-editor").length).to.be.equal(1)

    it "conteúdo alterado no servidor com o editor em modo de edição não sobrescreve o texto", ->
        elm = _compile("# Descrição")
        isolate = elm.isolateScope()
        isolate.setEditMode(true)
        isolate.markdown = "# Digitando..."

        scope.content = "# Descrição alterada pela T·IA"
        scope.$apply()

        expect(isolate.markdown).to.be.equal("# Digitando...")
        expect(_editor(elm).markdown).to.be.equal("# Descrição")

    it "conteúdo alterado no servidor com rascunho local não sobrescreve o texto", ->
        elm = _compile("# Descrição")
        isolate = elm.isolateScope()
        mocks.storage.get.withArgs(STORAGE_KEY).returns({version: 1, text: "# Rascunho"})

        scope.content = "# Descrição alterada pela T·IA"
        scope.$apply()

        expect(isolate.markdown).to.be.equal("# Descrição")
        expect(_editor(elm).markdown).to.be.equal("# Descrição")

    it "salvar renderiza o texto uma vez, sem re-renderização pela mudança de conteúdo", ->
        elm = _compile("# Descrição")
        isolate = elm.isolateScope()
        isolate.setEditMode(true)
        isolate.markdown = "# Salva pelo usuário"
        mocks.wysiwygService.refreshAttachmentURLFromMarkdown.reset()

        isolate.save()
        scope.$apply()

        expect(scope.onSave).to.have.been.calledOnce
        expect(mocks.wysiwygService.refreshAttachmentURLFromMarkdown).to.have.been.calledOnce
        expect(isolate.editMode).to.be.false
        expect(isolate.markdown).to.be.equal("# Salva pelo usuário")
        expect(_editor(elm).markdown).to.be.equal("# Salva pelo usuário")

    it "cancelar volta ao conteúdo do servidor", ->
        elm = _compile("# Descrição")
        isolate = elm.isolateScope()
        isolate.setEditMode(true)
        isolate.markdown = "# Digitando..."

        isolate.cancel()
        scope.$apply()

        expect(isolate.editMode).to.be.false
        expect(isolate.markdown).to.be.equal("# Descrição")
        expect(scope.onCancel).to.have.been.calledOnce
