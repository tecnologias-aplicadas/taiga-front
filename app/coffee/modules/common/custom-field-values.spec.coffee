###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "tgCustomAttributesValues", ->
    scope = compile = provide = $q = $rootScope = null
    mocks = {}

    ATTRIBUTE_ID = 7

    # Templates enxutos no lugar dos jade herdados: só o que a diretiva precisa para
    # alternar entre ver e editar
    _mockTemplate = ->
        mocks.template = {
            get: (name) ->
                switch name
                    when "custom-attributes/custom-attributes-values.html"
                        return (ctx) -> """
                            <div>
                                <div class="custom-attribute"
                                     ng-repeat="attr in ctrl.customAttributes"
                                     tg-custom-attribute-value="ctrl.getAttributeValue(attr)"
                                     required-edition-perm="#{ctx.requiredEditionPerm}"></div>
                            </div>
                        """
                    when "custom-attributes/custom-attribute-value.html"
                        return (ctx) -> "<div class='js-value-view-mode'><span class='value'>#{ctx.value}</span></div>"
                    when "custom-attributes/custom-attribute-value-edit.html"
                        return (ctx) -> "<form><input name='value' value='#{ctx.value}'></form>"
        }
        provide.value "$tgTemplate", mocks.template

    _mocks = ->
        module ($provide) ->
            provide = $provide
            _mockTemplate()
            mocks.storage = {get: sinon.stub().returns(false), set: sinon.stub()}
            provide.value "$tgStorage", mocks.storage
            mocks.rs = {customAttributesValues: {userstory: {get: sinon.stub()}}}
            provide.value "$tgResources", mocks.rs
            mocks.repo = {save: sinon.stub()}
            provide.value "$tgRepo", mocks.repo
            provide.value "$tgConfirm", {notify: sinon.stub()}
            provide.value "$selectedText", {get: -> ""}
            provide.value "tgDatePickerConfigService", {get: -> {}}
            provide.value "tgWysiwygService", {getHTML: (value) -> value}
            mocks.editingTracker = {begin: sinon.stub(), end: sinon.stub()}
            provide.value "tgEditingTracker", mocks.editingTracker
            provide.value "$translate", {instant: sinon.stub().returnsArg(0)}
            return null

    _values = (value) ->
        values = {}
        values[ATTRIBUTE_ID] = value
        return $q.resolve({id: 1, attributes_values: values})

    _compile = ->
        scope.us = {id: 1}
        scope.projectId = 1
        scope.project = {
            id: 1
            my_permissions: ["modify_us"]
            userstory_custom_attributes: [{id: ATTRIBUTE_ID, name: "Cliente", type: "text"}]
        }
        elm = compile("""
            <div tg-custom-attributes-values ng-model="us" type="userstory"
                 project="project" required-edition-perm="modify_us"></div>
        """)(scope)
        scope.$apply()
        return elm

    _shownValue = (elm) -> elm.find(".value").text()

    beforeEach ->
        module "taigaCommon"
        _mocks()

        inject ($compile, _$rootScope_, _$q_) ->
            $rootScope = _$rootScope_
            $q = _$q_
            scope = $rootScope.$new()
            compile = $compile

    it "carrega os valores uma vez ao abrir o card", ->
        mocks.rs.customAttributesValues.userstory.get.returns(_values("Antigo"))

        elm = _compile()

        expect(mocks.rs.customAttributesValues.userstory.get).to.have.been.calledOnce
        expect(_shownValue(elm)).to.be.equal("Antigo")

    it "recarga do card por evento reconsulta os valores e mostra o que o servidor devolveu", ->
        mocks.rs.customAttributesValues.userstory.get.returns(_values("Antigo"))
        elm = _compile()

        mocks.rs.customAttributesValues.userstory.get.returns(_values("Novo pela T·IA"))
        scope.$broadcast("custom-attributes-values:reload")
        scope.$apply()

        expect(mocks.rs.customAttributesValues.userstory.get).to.have.been.calledTwice
        expect(_shownValue(elm)).to.be.equal("Novo pela T·IA")

    it "valor igual ao já mostrado não re-renderiza", ->
        mocks.rs.customAttributesValues.userstory.get.returns(_values("Antigo"))
        elm = _compile()
        marker = elm.find(".js-value-view-mode")[0]

        scope.$broadcast("custom-attributes-values:reload")
        scope.$apply()

        expect(elm.find(".js-value-view-mode")[0]).to.be.equal(marker)

    it "com o campo aberto para edição, a reconsulta não fecha o campo e o valor novo aparece ao cancelar", ->
        mocks.rs.customAttributesValues.userstory.get.returns(_values("Antigo"))
        elm = _compile()

        elm.find(".js-value-view-mode").click()
        expect(elm.find("input[name=value]").length).to.be.equal(1)
        expect(mocks.editingTracker.begin).to.have.been.calledOnce

        mocks.rs.customAttributesValues.userstory.get.returns(_values("Novo pela T·IA"))
        scope.$broadcast("custom-attributes-values:reload")
        scope.$apply()

        expect(elm.find("input[name=value]").length).to.be.equal(1)
        expect(elm.find("input[name=value]").val()).to.be.equal("Antigo")

        esc = jQuery.Event("keyup")
        esc.keyCode = 27
        elm.find("input[name=value]").trigger(esc)

        expect(elm.find("input[name=value]").length).to.be.equal(0)
        expect(_shownValue(elm)).to.be.equal("Novo pela T·IA")
        expect(mocks.editingTracker.end).to.have.been.called

    it "salvar um valor pelo usuário continua com uma só chamada, a de salvar", ->
        mocks.rs.customAttributesValues.userstory.get.returns(_values("Antigo"))
        mocks.repo.save.returns($q.resolve())
        elm = _compile()
        ctrl = elm.controller("tgCustomAttributesValues")

        ctrl.updateAttributeValue({id: ATTRIBUTE_ID, value: "Digitado"})
        scope.$apply()

        expect(mocks.repo.save).to.have.been.calledOnce
        expect(mocks.rs.customAttributesValues.userstory.get).to.have.been.calledOnce
        expect(_shownValue(elm)).to.be.equal("Digitado")
