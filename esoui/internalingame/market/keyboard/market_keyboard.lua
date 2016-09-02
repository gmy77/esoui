ZO_KEYBOARD_MARKET_SCENE_NAME  = "market"
local MARKET_LABELED_GROUP_LABEL_TEMPLATE = "ZO_Market_GroupLabel"

ZO_MARKET_PREVIEW_DIRECTION_PREVIOUS = "previous"
ZO_MARKET_PREVIEW_DIRECTION_NEXT = "next"

ZO_MARKET_LIST_ENTRY_HEIGHT = 52

--
--[[ Market Content Fragment ]]--
--

local MarketContentFragment = ZO_SimpleSceneFragment:Subclass()

function MarketContentFragment:New(...)
    local fragment = ZO_SimpleSceneFragment.New(self, ...)
    fragment:Initialize(...)
    return fragment
end

function MarketContentFragment:Initialize(control, marketProductPool, marketProductBundlePool)
    self.control = control
    self.productList = control:GetNamedChild("ProductList")
    self.productListScrollChild = self.productList:GetNamedChild("ScrollChild")
    self.contentHeader = control:GetNamedChild("ContentHeader")
    self.cost = control:GetNamedChild("Cost")

    self.marketProductPool = ZO_MetaPool:New(marketProductPool)
    self.marketProductBundlePool = ZO_MetaPool:New(marketProductBundlePool)

    self.marketProducts = {}

    self:RegisterCallback("StateChange", function(...) self:OnStateChange(...) end)
end

function MarketContentFragment:OnStateChange(oldState, newState)
    if newState == SCENE_FRAGMENT_HIDDEN then
        self.marketProductPool:ReleaseAllObjects()
        self.marketProductBundlePool:ReleaseAllObjects()
        self.marketProduct = nil
    end
end

do
    local CURRENCY_ICON_SIZE = "100%"
    function MarketContentFragment:ShowMarketProductContents(marketProduct)
        self.marketProductPool:ReleaseAllObjects()
        self.marketProductBundlePool:ReleaseAllObjects()
        ZO_Scroll_ResetToTop(self.productList)
        ZO_ClearNumericallyIndexedTable(self.marketProducts)

        self.marketProduct = marketProduct

        self.contentHeader:SetText(marketProduct:GetMarketProductDisplayName())

        local currencyType, cost, hasDiscount, costAfterDiscount, discountPercent = marketProduct:GetMarketProductPricingByPresentation()
        local currencyIcon = ZO_Currency_GetPlatformFormattedCurrencyIcon(ZO_Currency_MarketCurrencyToUICurrency(currencyType), CURRENCY_ICON_SIZE, INHERIT_ICON_COLOR)
        local currencyString = zo_strformat(SI_CURRENCY_AMOUNT_WITH_ICON, ZO_CommaDelimitNumber(costAfterDiscount), currencyIcon)
        self.cost:SetText(currencyString)

        local numChildren = marketProduct:GetNumChildren()
        if numChildren > 0 then
            for childIndex = 1, numChildren do
                local childMarketProductId = marketProduct:GetChildMarketProductId(childIndex)

                local isBundle = GetMarketProductType(childMarketProductId) == MARKET_PRODUCT_TYPE_BUNDLE

                local pool = isBundle and self.marketProductBundlePool or self.marketProductPool
                local childMarketProduct = pool:AcquireObject()
                childMarketProduct:ShowAsChild(childMarketProductId)
                childMarketProduct:SetParent(self.productListScrollChild)

                local productInfo = {
                                product = childMarketProduct,
                                control = childMarketProduct:GetControl(),
                                name = childMarketProduct:GetMarketProductDisplayName(),
                                isBundle = isBundle,
                                stackCount = childMarketProduct:GetStackCount(),
                            }
                table.insert(self.marketProducts, productInfo)
            end

            table.sort(self.marketProducts, function(entry1, entry2)
                return MARKET:CompareMarketProducts(entry1, entry2)
            end)
        end

        MARKET.LayoutProductGrid(self.marketProducts)
    end
end

function MarketContentFragment:RefreshProducts()
    for index, productInfo in ipairs(self.marketProducts) do
        local product = productInfo.product
        product:Refresh()
    end
end

function MarketContentFragment:Purchase()
    if self.marketProduct then
        self.marketProduct:Purchase()
    end
end

function MarketContentFragment:CanPurchase()
    if self.marketProduct then
        return not self.marketProduct:IsPurchaseLocked()
    else
        return false
    end
end

--
--[[ Market List Fragment ]]--
--

local MarketListFragment = ZO_SimpleSceneFragment:Subclass()

function MarketListFragment:New(...)
    local fragment = ZO_SimpleSceneFragment.New(self, ...)
    fragment:Initialize(...)
    return fragment
end

function MarketListFragment:Initialize(control)
    self.control = control
    self.list = control:GetNamedChild("List")
    self.listHeader = control:GetNamedChild("ListHeader")
    self.contentHeader = control:GetNamedChild("ContentHeader")
    self.cost = control:GetNamedChild("Cost")

    -- initialize the scroll list
    ZO_ScrollList_Initialize(self.list)

    local function SetupEntry(...)
        self:SetupEntry(...)
    end

    local function OnEntryReset(...)
        self:OnEntryReset(...)
    end

    local NO_ON_HIDDEN_CALLBACK = nil
    local NO_SELECT_SOUND = nil
    ZO_ScrollList_AddDataType(self.list, 1, "ZO_MarketListEntry", ZO_MARKET_LIST_ENTRY_HEIGHT, SetupEntry, NO_ON_HIDDEN_CALLBACK, NO_SELECT_SOUND, OnEntryReset)
    ZO_ScrollList_AddResizeOnScreenResize(self.list)

    self.scrollData = ZO_ScrollList_GetDataList(self.list)
end

function MarketListFragment:SetupEntry(rowControl, data)
    rowControl.data = data
    rowControl.nameControl:SetText(zo_strformat(SI_MARKET_PRODUCT_NAME_FORMATTER, data.name))
    rowControl.iconControl:SetTexture(data.icon)

    if data.stackCount > 1 then
        rowControl.stackCount:SetText(data.stackCount)
        rowControl.stackCount:SetHidden(false)
    else
        rowControl.stackCount:SetHidden(true)
    end
end

function MarketListFragment:OnEntryReset(rowControl, data)
    local highlight = rowControl.highlight
    if highlight.animation then
        highlight.animation:PlayFromEnd(highlight.animation:GetDuration())
    end

    local icon = rowControl.iconControl
    if icon.animation then
        icon.animation:PlayInstantlyToStart()
    end

    rowControl.data = nil

    ZO_ObjectPool_DefaultResetControl(rowControl)
end

do
    local MARKET_PRODUCT_SORT_KEYS =
        {
            tierOrdering = { tiebreaker = "name", tieBreakerSortOrder = ZO_SORT_ORDER_UP },
            name = { tiebreaker = "stackCount", tieBreakerSortOrder = ZO_SORT_ORDER_DOWN },
            stackCount = {},
        }

    function MarketListFragment:CompareMarketProducts(entry1, entry2)
        return ZO_TableOrderingFunction(entry1, entry2, "tierOrdering", MARKET_PRODUCT_SORT_KEYS, ZO_SORT_ORDER_DOWN)
    end
end

function MarketListFragment:ShowCrownCrateContents(marketProduct)
    self.contentHeader:SetText(zo_strformat(SI_MARKET_PRODUCT_NAME_FORMATTER, marketProduct:GetMarketProductDisplayName()))
    self.listHeader:SetText(GetString(SI_MARKET_CRATE_LIST_HEADER))

    local marketProducts = {}

    local crateId = marketProduct:GetMarketProductCrownCrateId()

    local numTiers = GetNumCrownCrateTiers(crateId)
    for tierIndex = 1, numTiers do
        local tierId = GetCrownCrateTierId(crateId, tierIndex)
        local tierOrdering = GetCrownCrateTierOrdering(tierId)
        local numProducts = GetNumMarketProductsInCrownCrateTier(tierId)
        for productIndex = 1, numProducts do
            local productId = GetMarketProductIdFromCrownCrateTier(tierId, productIndex)
            local productInfo =
                {
                    productId = productId,
                    name = GetMarketProductDisplayName(productId),
                    stackCount = GetMarketProductStackCount(productId),
                    tierId = tierId,
                    tierOrdering = tierOrdering,
                }
            table.insert(marketProducts, productInfo)
        end
    end

    table.sort(marketProducts, function(...)
                return self:CompareMarketProducts(...)
            end)

    self:ShowMarketProducts(marketProducts)
end

-- marketProducts is a table of Market Product info
function MarketListFragment:ShowMarketProducts(marketProducts)
    ZO_ScrollList_Clear(self.list)
    ZO_ScrollList_ResetToTop(self.list)

    for i = 1, #marketProducts do
        local productInfo = marketProducts[i]
        local productId = productInfo.productId
        local name, description, icon, isNew, isFeatured = GetMarketProductInfo(productId)
        local stackCount = productInfo.stackCount

        local rowData =
            {
                productId = productId,
                name = name,
                icon = icon,
                stackCount = stackCount,
            }
        table.insert(self.scrollData, ZO_ScrollList_CreateDataEntry(1, rowData))
    end

    ZO_ScrollList_Commit(self.list)
end

local function SetListHighlightHidden(control, hidden)
    local highlight = control.highlight
    if not highlight.animation then
        highlight.animation = ANIMATION_MANAGER:CreateTimelineFromVirtual("ShowOnMouseOverLabelAnimation", highlight)
    end
    if hidden then
        highlight.animation:PlayBackward()
    else
        highlight.animation:PlayForward()
    end
end

function ZO_MarketListEntry_OnMouseEnter(control)
    SetListHighlightHidden(control, false)

    local icon = control.iconControl
    if not icon.animation then
        icon.animation = ANIMATION_MANAGER:CreateTimelineFromVirtual("IconSlotMouseOverAnimation", icon)
    end

    icon.animation:PlayForward()

    local offsetX = -15
    local offsetY = 0
    InitializeTooltip(ItemTooltip, control, RIGHT, offsetX, offsetY, LEFT)
    ItemTooltip:SetMarketProduct(control.data.productId)
end

function ZO_MarketListEntry_OnMouseExit(control)
    SetListHighlightHidden(control, true)

    local icon = control.iconControl
    if icon.animation then
        icon.animation:PlayBackward()
    end

    ClearTooltip(ItemTooltip)
end

--
--[[ Market ]]--
--

local Market = ZO_Market_Shared:Subclass()

function Market:New(...)
    return ZO_Market_Shared.New(self, ...)
end

function Market:Initialize(control)
    control.owner = self
    self.control = control

    self.currencyContainer = self.control:GetNamedChild("Currency")
    self.crownsContainer = self.currencyContainer:GetNamedChild("Crowns")
    self.crownsCurrencyLabel = self.crownsContainer:GetNamedChild("CurrencyValue")

    local crownsContainerWidth = self.crownsContainer:GetWidth()
    local crownsNameWidth = self.crownsContainer:GetNamedChild("CurrencyName"):GetWidth()
    self.crownsCurrencyLabel:SetWidth(crownsContainerWidth - crownsNameWidth)

    self.gemsContainer = self.currencyContainer:GetNamedChild("Gems")
    self.gemsCurrencyLabel = self.gemsContainer:GetNamedChild("CurrencyValue")

    local gemsContainerWidth = self.gemsContainer:GetWidth()
    local gemsNameWidth = self.gemsContainer:GetNamedChild("CurrencyName"):GetWidth()
    self.gemsCurrencyLabel:SetWidth(gemsContainerWidth - gemsNameWidth)

    self.messageLabel = self.control:GetNamedChild("MessageLabel")
    self.messageLoadingIcon = self.control:GetNamedChild("MessageLoadingIcon")
    self.rotationControl = self.control:GetNamedChild("RotationArea")
    self.previewVariationLeftArrow = self.control:GetNamedChild("PreviewVariationLeftArrow")
    self.previewVariationRightArrow = self.control:GetNamedChild("PreviewVariationRightArrow")
    self.variationLabel = self.control:GetNamedChild("VariationLabel")

    -- Crown Store Contents
    self.contentsControl = CreateControlFromVirtual("$(parent)Contents", self.control, "ZO_KeyboardMarketContents")
    self.contentsControl:ClearAnchors()
    self.contentsControl:SetAnchor(TOPLEFT, self.control, TOPLEFT, 0, 5)
    self.contentsControl:SetAnchor(BOTTOMRIGHT, self.control, BOTTOMRIGHT, -5, 0)

    self.contentFragment = ZO_SimpleSceneFragment:New(self.contentsControl)
    self.contentFragment:SetConditional(function()
                                            return self.shouldShowMarketContents
                                        end)

    self.noMatchesMessage = self.contentsControl:GetNamedChild("NoMatchMessage")
    self.searchBox = self.contentsControl:GetNamedChild("SearchBox")

    local subscriptionControl = self.contentsControl:GetNamedChild("SubscriptionPage")
    self.subscriptionPage = subscriptionControl
    local subscriptionSCrollChild = subscriptionControl:GetNamedChild("ScrollChild")
    self.subscriptionOverviewLabel = subscriptionSCrollChild:GetNamedChild("Overview")
    self.subscriptionStatusLabel = subscriptionSCrollChild:GetNamedChild("MembershipInfoStatus")
    self.subscriptionMembershipBanner = subscriptionSCrollChild:GetNamedChild("MembershipInfoBanner")
    self.subscriptionBenefitsLineContainer = subscriptionSCrollChild:GetNamedChild("BenefitsLineContainer")
    self.subscriptionSubscribeButton = subscriptionSCrollChild:GetNamedChild("SubscribeButton")

    self.subscriptionBenefitLinePool = ZO_ControlPool:New("ZO_Market_SubscriptionBenefitLine", control)

    self.nextPreviewChangeTime = 0
    self.canBeginPreview = true

    self.control:SetHandler("OnUpdate", function(control, currentTime) self:OnUpdate(currentTime) end)

    self:InitializeObjectPools()

    -- Bundle Contents
    self.bundleContentsControl = CreateControlFromVirtual("$(parent)BundleContents", self.control, "ZO_KeyboardBundleContents")
    self.bundleContentsControl:ClearAnchors()
    self.bundleContentsControl:SetAnchor(TOPLEFT, self.control, TOPLEFT, 0, 5)
    self.bundleContentsControl:SetAnchor(BOTTOMRIGHT, self.control, BOTTOMRIGHT, -5, 0)

    self.bundleContentFragment = MarketContentFragment:New(self.bundleContentsControl, self.masterMarketProductPool, self.masterMarketProductBundlePool)

    -- Product List
    self.productListControl = CreateControlFromVirtual("$(parent)ProductList", self.control, "ZO_KeyboardMarketProductList")
    self.productListControl:ClearAnchors()
    self.productListControl:SetAnchor(TOPLEFT, self.control, TOPLEFT, 0, 5)
    self.productListControl:SetAnchor(BOTTOMRIGHT, self.control, BOTTOMRIGHT, -5, 0)

    self.productListFragment = MarketListFragment:New(self.productListControl)

    -- ZO_Market_Shared.Initialize needs to be called after the control declarations
    -- This is because several overridden functions such as InitializeCategories and InitializeFilters called during initialization reference them
    ZO_Market_Shared.Initialize(self)
end

function Market:GetLabeledGroupLabelTemplate()
    return MARKET_LABELED_GROUP_LABEL_TEMPLATE
end

local CURRENCY_ICON_SIZE = 24
function Market:UpdateCrownBalance(amount)
    local crownsIcon = ZO_Currency_GetPlatformFormattedCurrencyIcon(ZO_Currency_MarketCurrencyToUICurrency(MKCT_CROWNS), CURRENCY_ICON_SIZE)
    local currencyString = zo_strformat(SI_CURRENCY_AMOUNT_WITH_ICON, ZO_CommaDelimitNumber(amount), crownsIcon)
    self.crownsCurrencyLabel:SetText(currencyString)
end

function Market:UpdateCrownGemBalance(amount)
    local gemsIcon = ZO_Currency_GetPlatformFormattedCurrencyIcon(ZO_Currency_MarketCurrencyToUICurrency(MKCT_CROWN_GEMS), CURRENCY_ICON_SIZE)
    local currencyString = zo_strformat(SI_CURRENCY_AMOUNT_WITH_ICON, ZO_CommaDelimitNumber(amount), gemsIcon)
    self.gemsCurrencyLabel:SetText(currencyString)
end

function Market:CanPreviewMarketProductPreviewType(previewType)
    if previewType == ZO_MARKET_PREVIEW_TYPE_BUNDLE then
        return not self.bundleContentFragment:IsShowing()
    elseif previewType == ZO_MARKET_PREVIEW_TYPE_CROWN_CRATE then
        return not self.productListFragment:IsShowing()
    else -- ZO_MARKET_PREVIEW_TYPE_PREVIEWABLE
        return self:IsReadyToPreview()
    end
end

function Market:InitializeKeybindDescriptors()
    self.keybindStripDescriptors =
    {
        alignment = KEYBIND_STRIP_ALIGN_RIGHT,

        -- End Preview Keybind
        {
            alignment = KEYBIND_STRIP_ALIGN_CENTER,
            name =      GetString(SI_MARKET_END_PREVIEW_KEYBIND_TEXT),
            keybind =   "UI_SHORTCUT_NEGATIVE",
            visible =   function()
                                local isPreviewing = self:GetPreviewState()
                                return isPreviewing
                        end,
            callback =  function()
                            local isPreviewing = self:GetPreviewState()
                            if isPreviewing then
                                self:EndCurrentPreview()
                            end
                        end,
        },

        -- "Preview" Keybind
        {
            name =      function()
                            local previewType = self.GetMarketProductPreviewType(self.selectedMarketProduct)
                            if previewType == ZO_MARKET_PREVIEW_TYPE_BUNDLE then
                                return GetString(SI_MARKET_BUNDLE_DETAILS_KEYBIND_TEXT)
                            else
                                return GetString(SI_MARKET_PREVIEW_KEYBIND_TEXT)
                            end
                        end,
            keybind =   "UI_SHORTCUT_SECONDARY",
            visible =   function()
                            local marketProduct = self.selectedMarketProduct
                            if marketProduct ~= nil then
                                local previewType = self.GetMarketProductPreviewType(marketProduct)

                                if previewType == ZO_MARKET_PREVIEW_TYPE_BUNDLE and marketProduct:GetHidesChildProducts() then
                                    return false
                                else
                                    return self:CanPreviewMarketProductPreviewType(previewType)
                                end
                            end
                            return false
                        end,
            callback =  function()
                            local marketProduct = self.selectedMarketProduct

                            local previewType = self.GetMarketProductPreviewType(marketProduct)
                            if previewType == ZO_MARKET_PREVIEW_TYPE_BUNDLE then
                                self:ShowBundleContents(marketProduct)
                            elseif previewType == ZO_MARKET_PREVIEW_TYPE_CROWN_CRATE then
                                self:ShowCrownCrateContents(marketProduct)
                            else -- ZO_MARKET_PREVIEW_TYPE_PREVIEWABLE
                                marketProduct.variation = 1
                                self:BeginPreview()
                                self:SetCanBeginPreview(false, GetFrameTimeSeconds())
                            end
                        end,
            enabled =   function()
                            local previewType = self.GetMarketProductPreviewType(marketProduct)
                            if previewType == ZO_MARKET_PREVIEW_TYPE_PREVIEWABLE then
                                return self.canBeginPreview
                            else
                                return true
                            end
                        end,
        },

        -- Purchase Keybind
        {
            name =  function()
                        if self.bundleContentFragment:IsShowing() then
                            return GetString(SI_MARKET_PURCHASE_BUNDLE_KEYBIND_TEXT)
                        else
                            if self.selectedMarketProduct:IsBundle() then
                                return GetString(SI_MARKET_PURCHASE_BUNDLE_KEYBIND_TEXT)
                            else
                                return GetString(SI_MARKET_PURCHASE_KEYBIND_TEXT)
                            end
                        end
                    end,
            keybind = "UI_SHORTCUT_PRIMARY",
            visible =   function()
                            if self.bundleContentFragment:IsShowing() then
                                return self.bundleContentFragment:CanPurchase()
                            else
                                return self.selectedMarketProduct ~= nil and not self.selectedMarketProduct:IsPurchaseLocked()
                            end
                        end,
            callback =  function()
                            if self.bundleContentFragment:IsShowing() then
                                self.bundleContentFragment:Purchase()
                            else
                                self.selectedMarketProduct:Purchase()
                            end
                        end,
        },
    }
end

do
    -- Map from enum to keyboard specific strings
    local MARKET_FILTERS =
    {
        [MARKET_FILTER_VIEW_ALL] = SI_MARKET_FILTER_SHOW_ALL,
        [MARKET_FILTER_VIEW_PURCHASED] = SI_MARKET_FILTER_SHOW_PURCHASED,
        [MARKET_FILTER_VIEW_NOT_PURCHASED] = SI_MARKET_FILTER_SHOW_NOT_PURCHASED,
    }

    function Market:InitializeFilters()
        self.categoryFilter = self.contentsControl:GetNamedChild("Filter")
        self.categoryFilterLabel = self.contentsControl:GetNamedChild("FilterLabel")

        local comboBox = ZO_ComboBox_ObjectFromContainer(self.categoryFilter)
        comboBox:SetSortsItems(false)
        comboBox:SetFont("ZoFontWinT1")
        comboBox:SetSpacing(4)
    
        local function OnFilterChanged(comboBox, entryText, entry)
            self.categoryFilter.filterType = entry.filterType
            self:RefreshVisibleCategoryFilter()
        end

        for i, stringId in ipairs(MARKET_FILTERS) do
            local entry = comboBox:CreateItemEntry(GetString(stringId), OnFilterChanged)
            entry.filterType = i
            comboBox:AddItem(entry)
        end

        comboBox:SelectFirstItem()
    end
end

function Market:CreateMarketScene()
    local scene = ZO_RemoteScene:New(ZO_KEYBOARD_MARKET_SCENE_NAME, SCENE_MANAGER)
    SYSTEMS:RegisterKeyboardRootScene(ZO_MARKET_NAME, scene)
    self:SetMarketScene(scene)

    self.marketScene:AddFragment(self.contentFragment)
end

function Market:InitializeCategories()
    self.categories = self.contentsControl:GetNamedChild("Categories")
    self.categoryTree = ZO_Tree:New(self.categories:GetNamedChild("ScrollChild"), 60, -10, 300)

    local function BaseTreeHeaderIconSetup(control, data, open)
        local iconTexture = (open and data.pressedIcon or data.normalIcon) or "EsoUI/Art/Icons/icon_missing.dds"
        local mouseoverTexture = data.mouseoverIcon or "EsoUI/Art/Icons/icon_missing.dds"
        
        control.icon:SetTexture(iconTexture)
        control.iconHighlight:SetTexture(mouseoverTexture)

        ZO_IconHeader_Setup(control, open)
    end

    local function BaseTreeHeaderSetup(node, control, data, open)
        control.text:SetModifyTextType(MODIFY_TEXT_TYPE_UPPERCASE)
        control.text:SetText(data.name)
        BaseTreeHeaderIconSetup(control, data, open)
    end

    local function TreeHeaderSetup_Child(node, control, data, open, userRequested)
        BaseTreeHeaderSetup(node, control, data, open)

        if open and userRequested then
            self.categoryTree:SelectFirstChild(node)
        end
    end

    local function TreeHeaderSetup_Childless(node, control, data, open)
        BaseTreeHeaderSetup(node, control, data, open)
    end

    local function TreeEntryOnSelected(control, data, selected, reselectingDuringRebuild)
        control:SetSelected(selected)

        if selected and not reselectingDuringRebuild then
            self:OnCategorySelected(data)

            local categoryIndex, subCategoryIndex
            -- faked category types don't have real category indices so keep them as nil
            if data.type == ZO_MARKET_CATEGORY_TYPE_NONE then
                if data.parentData then
                    categoryIndex = data.parentData.categoryIndex
                    subCategoryIndex = data.categoryIndex
                else
                    categoryIndex = data.categoryIndex
                end
            end

            OnMarketCategorySelected(categoryIndex, subCategoryIndex)
        end
    end

    local function TreeHeaderOnSelected_Childless(control, data, selected, reselectingDuringRebuild)
        TreeEntryOnSelected(control, data, selected, reselectingDuringRebuild)
        BaseTreeHeaderIconSetup(control, data, selected)
    end

    local DEFAULT_NOT_SELECTED = false
    local function TreeEntrySetup(node, control, data, open)
        control:SetText(data.name)
        control:SetSelected(DEFAULT_NOT_SELECTED)
    end
    
    self.categoryTree:AddTemplate("ZO_IconHeader", TreeHeaderSetup_Child, nil, nil, 60, 0)
    self.categoryTree:AddTemplate("ZO_MarketChildlessCategory", TreeHeaderSetup_Childless, TreeHeaderOnSelected_Childless)
    self.categoryTree:AddTemplate("ZO_MarketSubCategory", TreeEntrySetup, TreeEntryOnSelected)

    self.categoryTree:SetExclusive(true) --only one header open at a time
    self.categoryTree:SetOpenAnimation("ZO_TreeOpenAnimation")
end

function Market:InitializeMarketList()
    self.marketProductList = self.contentsControl:GetNamedChild("EntryList")
    self.marketScrollChild = self.marketProductList:GetNamedChild("ScrollChild")

    -- override the default functionality when the extants change for the product list so we can scroll to a specific item
    -- if one exists because we openned the market to see a specific item
    self.marketProductList.scroll:SetHandler("OnScrollExtentsChanged",  function(control)
                                                                            ZO_Scroll_OnExtentsChanged(control:GetParent()) 
                                                                            self:ScrollAndPreviewQueuedMarketProduct()
                                                                        end)
end

function Market:InitializeObjectPools()
    -- MarketProductIcon Pool

    local function CreateMarketProductIcon(objectPool)
        -- parent will be changed to the MarketProduct that uses the icon
        return ZO_MarketProductIcon:New(objectPool:GetNextControlId(), self.marketScrollChild, self.marketProductIconPool)
    end
    
    local function ResetMarketProductIcon(marketProductIcon)
        marketProductIcon:Reset()
    end

    self.marketProductIconPool = ZO_ObjectPool:New(CreateMarketProductIcon, ResetMarketProductIcon)

    -- ZO_MarketProductIndividual Pool

    local function CreateMarketProduct(objectPool)
        return ZO_MarketProductIndividual:New(objectPool:GetNextControlId(), self.marketScrollChild, self.marketProductIconPool, self)
    end
    
    local function ResetMarketProduct(marketProduct)
        marketProduct:Reset()
    end

    self.masterMarketProductPool = ZO_ObjectPool:New(CreateMarketProduct, ResetMarketProduct)

    self.marketProductPool = ZO_MetaPool:New(self.masterMarketProductPool)

    -- ZO_MarketProductBundle Pool

    local function CreateMarketProductBundle(objectPool)
        return ZO_MarketProductBundle:New(objectPool:GetNextControlId(), self.marketScrollChild, self.marketProductIconPool, self)
    end
    
    local function ResetMarketProductBundle(marketProductBundle)
        marketProductBundle:Reset()
    end

    self.masterMarketProductBundlePool = ZO_ObjectPool:New(CreateMarketProductBundle, ResetMarketProductBundle)

    self.marketProductBundlePool = ZO_MetaPool:New(self.masterMarketProductBundlePool)
end

function Market:BuildCategories()
    local currentCategory = self.currentCategoryData
    self.categoryTree:Reset()
    self.nodeLookupData = {}

    if self.searchString == "" then
        --Special featured items blade
        local numFeaturedMarketProducts = GetNumFeaturedMarketProducts()
        if numFeaturedMarketProducts > 0 then
            local normalIcon = "esoui/art/treeicons/achievements_indexicon_summary_up.dds"
            local pressedIcon = "esoui/art/treeicons/achievements_indexicon_summary_down.dds"
            local mouseoverIcon = "esoui/art/treeicons/achievements_indexicon_summary_over.dds"
            self:AddTopLevelCategory(ZO_MARKET_FEATURED_CATEGORY_INDEX, GetString(SI_MARKET_FEATURED_CATEGORY), 0, normalIcon, pressedIcon, mouseoverIcon, ZO_MARKET_CATEGORY_TYPE_FEATURED)
        end

        local normalIcon = "esoui/art/treeicons/store_indexIcon_ESOPlus_up.dds"
        local pressedIcon = "esoui/art/treeicons/store_indexIcon_ESOPlus_down.dds"
        local mouseoverIcon = "esoui/art/treeicons/store_indexIcon_ESOPlus_over.dds"
        self:AddTopLevelCategory(ZO_MARKET_ESO_PLUS_CATEGORY_INDEX, GetString(SI_MARKET_ESO_PLUS_CATEGORY), 0, normalIcon, pressedIcon, mouseoverIcon, ZO_MARKET_CATEGORY_TYPE_ESO_PLUS)

        for i = 1, GetNumMarketProductCategories() do
            local name, numSubCategories, numMarketProducts, normalIcon, pressedIcon, mouseoverIcon = GetMarketProductCategoryInfo(i)
            self:AddTopLevelCategory(i, name, numSubCategories, normalIcon, pressedIcon, mouseoverIcon)
        end
    else
        for categoryIndex, data in pairs(self.searchResults) do
            local name, numSubCategories, numMarketProducts, normalIcon, pressedIcon, mouseoverIcon = GetMarketProductCategoryInfo(categoryIndex)
            self:AddTopLevelCategory(categoryIndex, name, numSubCategories, normalIcon, pressedIcon, mouseoverIcon)
        end
    end
    
    local nodeToSelect
    if currentCategory then
        local categoryIndex
        local subcatgoryIndex
        local parentData = currentCategory.parentData
        if parentData then
            categoryIndex = parentData.categoryIndex
            subcatgoryIndex = currentCategory.categoryIndex
        else
            categoryIndex = currentCategory.categoryIndex
        end
        nodeToSelect = self:GetCategoryData(categoryIndex, subcatgoryIndex)
    end

    self.categoryTree:Commit(nodeToSelect)

    self.refreshCategories = false
end

function Market:RefreshVisibleCategoryFilter()
    local data = self.categoryTree:GetSelectedData()
    if data ~= nil then
        self:OnCategorySelected(data)
    end
end

do
    local function AddNodeLookup(lookup, node, parent, categoryIndex)
        if categoryIndex ~= nil then
            local parentCategory = categoryIndex
            local subCategory

            if parent then
                parentCategory = parent.data.categoryIndex
                subCategory = categoryIndex
            end

            local categoryTable = lookup[parentCategory]
            
            if categoryTable == nil then
                categoryTable = { subCategories = {} }
                lookup[parentCategory] = categoryTable
            end

            if subCategory then
                categoryTable.subCategories[subCategory] = node
            else
                categoryTable.node = node
            end
        end
    end

    function Market:GetCategoryData(categoryIndex, subCategoryIndex)
        if categoryIndex ~= nil then
            local categoryTable = self.nodeLookupData[categoryIndex]
            if categoryTable ~= nil then
                if subCategoryIndex ~= nil then
                    return categoryTable.subCategories[subCategoryIndex]
                else
                    if categoryTable.node:IsLeaf() then
                        return categoryTable.node
                    else
                        return categoryTable.node:GetChildren()[1]
                    end
                end
            end
        end
    end

    function Market:GetMarketProductInfo(productId)
        for i = 1, #self.marketProducts do
            if self.marketProducts[i].product:GetId() == productId then
                return self.marketProducts[i]
            end
        end

        for i = 1, #self.featuredProducts do
            if self.featuredProducts[i].product:GetId() == productId then
                return self.featuredProducts[i]
            end
        end

        for i = 1, #self.limitedTimedOfferProducts do
            if self.limitedTimedOfferProducts[i].product:GetId() == productId then
                return self.limitedTimedOfferProducts[i]
            end
        end
    end

    function Market:RequestShowMarketProduct(id)
        if self.marketState ~= MARKET_STATE_OPEN then
            self.queuedMarketProductId = id
            return
        end

        local targetNode = self:GetCategoryDataForMarketProduct(id)
        if targetNode then
            if self.categoryTree:GetSelectedNode() == targetNode then
                self:ScrollAndPreviewMarketProduct(id)
            else
                self.categoryTree:SelectNode(targetNode)
                self.queuedMarketProductId = id -- order of operations is important here
            end
        end
    end

    local INSTANTLY_SCROLL_TO_CENTER = true
    function Market:ScrollAndPreviewMarketProduct(marketProductId)
        local marketProductInfo = self:GetMarketProductInfo(marketProductId)
        if marketProductInfo then
            ZO_Scroll_ScrollControlIntoCentralView(self.marketProductList, marketProductInfo.control, INSTANTLY_SCROLL_TO_CENTER)
            marketProductInfo.product:PlayHighlightAnimationToEnd()
            self.queuedMarketProductPreview = marketProductInfo.product
        end
    end

    function Market:ScrollAndPreviewQueuedMarketProduct()
        self:ScrollAndPreviewMarketProduct(self.queuedMarketProductId)
        self.queuedMarketProductId = nil
    end

    function Market:RequestShowMarketWithSearchString(searchString)
        if self.marketState ~= MARKET_STATE_OPEN then
            self.queuedSearchString = searchString
            return
        end

        self:DisplayMarketProductsBySearchString(searchString)
    end

    function Market:DisplayMarketProductsBySearchString(searchString)
        self.searchBox:SetText(searchString)
    end

    function Market:DisplayQueuedMarketProductsBySearchString()
        self:DisplayMarketProductsBySearchString(self.queuedSearchString)
        self.queuedSearchString = nil
    end

    local function AddCategory(lookup, tree, nodeTemplate, parent, categoryIndex, name, normalIcon, pressedIcon, mouseoverIcon, categoryType, isFakedSubcategory)
        categoryType = categoryType or ZO_MARKET_CATEGORY_TYPE_NONE
        local entryData = 
        {
            isFakedSubcategory = isFakedSubcategory,
            categoryIndex = categoryIndex,
            name = zo_strformat(SI_MARKET_PRODUCT_NAME_FORMATTER, name),
            type = categoryType,
            parentData = parent and parent.data or nil,
            normalIcon = normalIcon,
            pressedIcon = pressedIcon,
            mouseoverIcon = mouseoverIcon,
        }

        local soundId = parent and SOUNDS.MARKET_SUB_CATEGORY_SELECTED or SOUNDS.MARKET_CATEGORY_SELECTED
        local node = tree:AddNode(nodeTemplate, entryData, parent, soundId)
        entryData.node = node

        finalCategoryIndex = isFakedSubcategory and "root" or categoryIndex
        AddNodeLookup(lookup, node, parent, finalCategoryIndex)
        return node
    end

    function Market:AddTopLevelCategory(categoryIndex, name, numSubCategories, normalIcon, pressedIcon, mouseoverIcon, categoryType)
        local tree = self.categoryTree
        local lookup = self.nodeLookupData

        -- Either there's more than one subcategory found, or the subcategory found isn't "general", thus children
        local hasSearchResults = self.searchString ~= ""
        local searchResultsWithChildren = hasSearchResults and (NonContiguousCount(self.searchResults[categoryIndex]) > 1 or self.searchResults[categoryIndex]["root"] == nil)
        local hasChildren = numSubCategories > 0 --Only for non-search results

        -- Select the correct template for the parent based on whether or not we will show any subcategories
        local nodeTemplate
        if hasSearchResults then
            -- if we have search results we will only have children if we have a real subcategory
            -- if we only have the root subcategory, we do not add it
            nodeTemplate = searchResultsWithChildren and "ZO_IconHeader" or "ZO_MarketChildlessCategory"
        else
            -- if we are not searching, we only have children if the category has subcategories
            nodeTemplate = hasChildren and "ZO_IconHeader" or "ZO_MarketChildlessCategory"
        end

        local parent = AddCategory(lookup, tree, nodeTemplate, nil, categoryIndex, name, normalIcon, pressedIcon, mouseoverIcon, categoryType)

        if hasSearchResults then
            if searchResultsWithChildren and self.searchResults[categoryIndex]["root"] then
                local isFakedSubcategory = true
                local categoryName = GetMarketProductCategoryInfo(categoryIndex)
                AddCategory(lookup, tree, "ZO_MarketSubCategory", parent, categoryIndex, GetString(SI_MARKET_GENERAL_SUBCATEGORY), normalIcon, pressedIcon, mouseoverIcon, ZO_MARKET_CATEGORY_TYPE_NONE, isFakedSubcategory)
            end

            for subcategoryIndex, data in pairs(self.searchResults[categoryIndex]) do
                if subcategoryIndex ~= "root" then
                    local subCategoryName = GetMarketProductSubCategoryInfo(categoryIndex, subcategoryIndex)
                    AddCategory(lookup, tree, "ZO_MarketSubCategory", parent, subcategoryIndex, subCategoryName, normalIcon, pressedIcon, mouseoverIcon)
                end
            end
        elseif hasChildren then
            local numMarketProducts = select(3, GetMarketProductCategoryInfo(categoryIndex))
            if numMarketProducts > 0 then
                local isFakedSubcategory = true
                AddCategory(lookup, tree, "ZO_MarketSubCategory", parent, categoryIndex, GetString(SI_MARKET_GENERAL_SUBCATEGORY), normalIcon, pressedIcon, mouseoverIcon, ZO_MARKET_CATEGORY_TYPE_NONE, isFakedSubcategory)
            end

            for i = 1, numSubCategories do
                local subCategoryName = GetMarketProductSubCategoryInfo(categoryIndex, i)
                AddCategory(lookup, tree, "ZO_MarketSubCategory", parent, i, subCategoryName, normalIcon, pressedIcon, mouseoverIcon)
            end
        end

        return parent
    end
end

-- ... is a list of tables containing product ids and presentationIndexes
function Market:GetMarketProductIds(categoryIndex, subCategoryIndex, index, ...)
    if index >= 1 then
        if self.searchString ~= "" then
            if NonContiguousCount(self.searchResults) == 0 then
                return ...
            end

            local effectiveSubcategoryIndex = subCategoryIndex or "root"
            if not self.searchResults[categoryIndex][effectiveSubcategoryIndex][index] then
                index = index - 1
                return self:GetMarketProductIds(categoryIndex, subCategoryIndex, index, ...)
            end
        end

        local id, presentationIndex = GetMarketProductPresentationIds(categoryIndex, subCategoryIndex, index)
        local presentationInfo =    {
                                        id = id,
                                        presentationIndex = presentationIndex,
                                    }
        index = index - 1
        return self:GetMarketProductIds(categoryIndex, subCategoryIndex, index, presentationInfo, ...)
    end
    return ...
end

function Market:AddLabeledGroupTable(labeledGroupName, labeledGroupTable)
    ZO_Market_Shared.AddLabeledGroupTable(self, labeledGroupName, labeledGroupTable)

    self.previousRowControl = self.LayoutProductGrid(labeledGroupTable, self.previousRowControl, labeledGroupName, self.labeledGroupLabelPool)
end

do
    local ROW_PADDING = 10
    local NUM_COLUMNS = 2
    local LABELED_GROUP_PADDING = 70
    local FIRST_LABELED_GROUP_PADDING = 40
    local LABELED_GROUP_LABEL_PADDING = -20
    function Market.LayoutProductGrid(marketProductInfos, previousRowControl, sectionHeader, labelPool)
        local previousRowControl = previousRowControl
        local previousControl
        local currentColumn = 1
        for index, productInfo in ipairs(marketProductInfos) do
            local marketProduct = productInfo.product
            local marketControl = marketProduct:GetControl()
            marketControl:ClearAnchors()

            local isBundle = productInfo.isBundle
            if isBundle and currentColumn ~= 1 then
                currentColumn = 1 -- make sure the bundle is on a new line, it takes 2 spots
            end

            if currentColumn == 1 then
                if previousRowControl then
                    local extraYPadding = 0
                    if index == 1 and sectionHeader then
                        extraYPadding = LABELED_GROUP_PADDING
                    end
                    marketControl:SetAnchor(TOPLEFT, previousRowControl, BOTTOMLEFT, 0, ROW_PADDING + extraYPadding)
                else
                    marketControl:SetAnchor(TOPLEFT, nil, TOPLEFT, 0, sectionHeader and FIRST_LABELED_GROUP_PADDING or 0)
                end

                if index == 1 and sectionHeader and labelPool then
                    local sectionLabel = labelPool:AcquireObject()
                    sectionLabel:SetText(sectionHeader)
                    sectionLabel:SetParent(marketControl)
                    sectionLabel:ClearAnchors()
                    sectionLabel:SetAnchor(BOTTOMLEFT, marketControl, TOPLEFT, 0, LABELED_GROUP_LABEL_PADDING)
                end

                previousRowControl = marketControl
            else
                marketControl:SetAnchor(LEFT, previousControl, RIGHT, ZO_MARKET_PRODUCT_COLUMN_PADDING, 0)
            end

            if isBundle then
                currentColumn = 1 -- make sure the next item goes on a new line
            else
                currentColumn = currentColumn + 1
                if currentColumn > NUM_COLUMNS then
                    currentColumn = 1
                end
            end

            previousControl = marketControl
        end
        
        return previousRowControl
    end
end

function Market:ClearMarketProducts()
    self.marketProductPool:ReleaseAllObjects()
    self.marketProductBundlePool:ReleaseAllObjects()
    self:ClearLabeledGroups()
    ZO_Scroll_ResetToTop(self.marketProductList)
    self.previousRowControl = nil
end

function Market:DisplayEsoPlusOffer()
    self:ClearMarketProducts()
    self.subscriptionBenefitLinePool:ReleaseAllObjects()

    self.subscriptionPage:SetHidden(false)
    self.categoryFilter:SetHidden(true)
    self.categoryFilterLabel:SetHidden(true)

    local overview, image = GetMarketSubscriptionKeyboardInfo()

    self.subscriptionOverviewLabel:SetText(overview)
    self.subscriptionMembershipBanner:SetTexture(image)

    local numLines = GetNumKeyboardMarketSubscriptionBenefitLines()
    local controlToAnchorTo = self.subscriptionBenefitsLineContainer
    for i = 1, numLines do
        local line = GetKeyboardMarketSubscriptionBenefitLine(i);
        local benefitLine = self.subscriptionBenefitLinePool:AcquireObject()
        benefitLine:SetText(line)
        benefitLine:ClearAnchors()
        if i == 1 then
            benefitLine:SetAnchor(TOPLEFT, controlToAnchorTo, TOPLEFT, 0, 4)
        else
            benefitLine:SetAnchor(TOPLEFT, controlToAnchorTo, BOTTOMLEFT, 0, 4)
        end
        benefitLine:SetParent(self.subscriptionBenefitsLineContainer)
        controlToAnchorTo = benefitLine
    end

    local isSubscribed = IsESOPlusSubscriber()
    local statusText = isSubscribed and SI_MARKET_SUBSCRIPTION_PAGE_SUBSCRIPTION_STATUS_ACTIVE or SI_MARKET_SUBSCRIPTION_PAGE_SUBSCRIPTION_STATUS_NOT_ACTIVE

    self.subscriptionSubscribeButton:SetHidden(isSubscribed)

    self.subscriptionStatusLabel:SetText(GetString(statusText))

    ZO_Scroll_OnExtentsChanged(self.subscriptionPage)
end

local NO_LABELED_GROUP_HEADER = nil
function Market:LayoutMarketProducts(...)
    self:ClearMarketProducts()

    self.subscriptionPage:SetHidden(true)
    self.categoryFilter:SetHidden(false)
    self.categoryFilterLabel:SetHidden(false)

    local categoryType = self.currentCategoryData.type

    local filterType = self.categoryFilter.filterType
    local hasShownProduct = false
    for i = 1, select("#", ...) do
        local presentationInfo = select(i, ...)
        local id = presentationInfo.id
        if self:ShouldAddMarketProduct(filterType, id) then
            hasShownProduct = true
            local isBundle = GetMarketProductType(id) == MARKET_PRODUCT_TYPE_BUNDLE

            local pool = isBundle and self.marketProductBundlePool or self.marketProductPool
            local marketProduct = pool:AcquireObject()
            local presentationIndex = presentationInfo.presentationIndex
            marketProduct:Show(id, presentationIndex)
            marketProduct:SetParent(self.marketScrollChild)

            local name, description, icon, isNew, isFeatured = marketProduct:GetMarketProductInfo()
            local timeLeft = marketProduct:GetTimeLeftInSeconds()
            -- durations longer than 1 month aren't represented to the user, so it's effectively not limited time
            local isLimitedTime = timeLeft > 0 and timeLeft <= ZO_ONE_MONTH_IN_SECONDS
            local doesContainDLC = DoesMarketProductContainDLC(id)

            -- only show the market product in the featured section or the all section
            if doesContainDLC and categoryType == ZO_MARKET_CATEGORY_TYPE_FEATURED then
                self:AddProductToLabeledGroupTable(self.dlcProducts, name, marketProduct)
            else
                if isLimitedTime then
                    self:AddProductToLabeledGroupTable(self.limitedTimedOfferProducts, name, marketProduct)
                elseif isFeatured then
                    self:AddProductToLabeledGroupTable(self.featuredProducts, name, marketProduct)
                else
                    self:AddProductToLabeledGroupTable(self.marketProducts, name, marketProduct)
                end
            end
        end
    end

    if #self.limitedTimedOfferProducts > 0 then
        self:AddLabeledGroupTable(GetString(SI_MARKET_LIMITED_TIME_OFFER_CATEGORY), self.limitedTimedOfferProducts)
    end

    if #self.dlcProducts > 0 then
        self:AddLabeledGroupTable(GetString(SI_MARKET_DLC_CATEGORY), self.dlcProducts)
    end

    if #self.featuredProducts > 0 then
        if categoryType == ZO_MARKET_CATEGORY_TYPE_NONE then
            self:AddLabeledGroupTable(GetString(SI_MARKET_FEATURED_CATEGORY), self.featuredProducts)
        else -- featured
            self:AddLabeledGroupTable(GetString(SI_MARKET_ALL_LABEL), self.featuredProducts)
        end
    end

    local categoryHeader = (#self.labeledGroups > 0) and GetString(SI_MARKET_ALL_LABEL) or NO_LABELED_GROUP_HEADER
    self:AddLabeledGroupTable(categoryHeader, self.marketProducts)
    self:ShowNoMatchesMessage(not hasShownProduct)
end

function Market:ShowMarket(showMarket)
    ZO_Market_Shared.ShowMarket(self, showMarket)

    -- if the Market is locked (showMarket == false) then we don't want to show the
    -- Category tree and the MarketProduct scroll area, so set this flag
    -- so the content fragment can hide appropriately
    self.shouldShowMarketContents = showMarket

    self.marketScene:AddFragment(self.contentFragment)
    self.marketScene:RemoveFragment(self.bundleContentFragment)
    self.marketScene:RemoveFragment(self.productListFragment)
    self.contentFragment:Refresh() -- make sure the contents show/hide appropriately
    self.currencyContainer:SetHidden(not showMarket)
    self.messageLabel:SetHidden(showMarket)
    self.rotationControl:SetHidden(not showMarket)
    if showMarket then
        -- hide the market products and show our no matches message if search has no results
        local showMessage = self.searchString ~= "" and NonContiguousCount(self.searchResults) == 0
        self:ShowNoMatchesMessage(showMessage)
        self.messageLoadingIcon:Hide()
    end
end

function Market:ShowNoMatchesMessage(showMessage)
    self.marketProductList:SetHidden(showMessage)
    self.noMatchesMessage:SetHidden(not showMessage)
end

function Market:ShowBundleContents(marketProduct)
    self:EndCurrentPreview()

    self.marketScene:RemoveFragment(self.contentFragment)
    self.marketScene:RemoveFragment(self.productListFragment)
    self.marketScene:AddFragment(self.bundleContentFragment)
    self.bundleContentFragment:ShowMarketProductContents(marketProduct)
end

function Market:ShowCrownCrateContents(marketProduct)
    self:EndCurrentPreview()

    self.marketScene:RemoveFragment(self.contentFragment)
    self.marketScene:RemoveFragment(self.bundleContentFragment)
    self.marketScene:AddFragment(self.productListFragment)
    self.productListFragment:ShowCrownCrateContents(marketProduct)
end

function Market:OnMarketUpdate()
    if MARKET_TREE_UNDERLAY_FRAGMENT then
        MARKET_TREE_UNDERLAY_FRAGMENT:Refresh()
    end
end

function Market:OnMarketLocked()
    self.messageLabel:SetText(GetString(SI_MARKET_LOCKED_TEXT))
    self:ShowMarket(false)
    self.messageLoadingIcon:Hide()
end

function Market:OnMarketLoading()
    if self.showLoadingText then
        self.messageLabel:SetText(GetString(SI_GAMEPAD_MARKET_PRESCENE_LOADING))
        self.messageLoadingIcon:Show()
    end
    self:ShowMarket(false)
end

function Market:MarketProductSelected(marketProduct)
    self.selectedMarketProduct = marketProduct
    self:RefreshActions()
end

function Market:RefreshActions()
    self:RefreshKeybinds()
    local cursor = self:IsReadyToPreview() and MOUSE_CURSOR_PREVIEW or MOUSE_CURSOR_DO_NOT_CARE
    WINDOW_MANAGER:SetMouseCursor(cursor)
end

do
    local PREVIEW_WAIT_TIME_SECONDS = ZO_MARKET_PREVIEW_WAIT_TIME_MS / 1000
    function Market:SetCanBeginPreview(canBeginPreview, lastChangeTimeSeconds)
        self.canBeginPreview = canBeginPreview
        self.nextPreviewChangeTime = lastChangeTimeSeconds + PREVIEW_WAIT_TIME_SECONDS
        self:RefreshKeybinds()

        if canBeginPreview then
            self.variationLabel:SetColor(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_NORMAL))
        else
            self.variationLabel:SetColor(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_DISABLED))
        end
    end
end

function Market:GetCanBeginPreview()
    return self.canBeginPreview
end

do
    local DISPLAY_LOADING_DELAY_SECONDS = ZO_MARKET_DISPLAY_LOADING_DELAY_MS / 1000
    function Market:OnUpdate(currentTime)
        if(not self.canBeginPreview and (currentTime >= self.nextPreviewChangeTime)) then
            self:SetCanBeginPreview(true, currentTime)
        end

        if self.marketState == MARKET_STATE_UNKNOWN then
            if self.loadingStartTime == nil then
                self.loadingStartTime = currentTime
            end

            if currentTime - self.loadingStartTime >= DISPLAY_LOADING_DELAY_SECONDS then
                self.showLoadingText = true
                self:OnMarketLoading()
            end
        else
            self.showLoadingText = false
            loadingStartTime = nil
        end
    end
end

function Market:OnShown()
    BeginPreviewMode()
    self:AddKeybinds()
    ZO_Market_Shared.OnShown(self)

    if self.refreshCategories then
        self:BuildCategories()
    end

    if self.queuedMarketProductPreview and IsCharacterPreviewingAvailable() then
        self.queuedMarketProductPreview:Preview()
        self.queuedMarketProductPreview = nil
    end
end

function Market:OnHidden()
    self:RemoveKeybinds()
    ZO_Dialogs_ReleaseAllDialogs()
    -- make sure we exit the bundle viewer when we close the market
    self.marketScene:AddFragment(self.contentFragment)
    self.marketScene:RemoveFragment(self.bundleContentFragment)
end

function Market:RefreshProducts()
    for i = 1, #self.marketProducts do
        local product = self.marketProducts[i].product
        product:Refresh()
    end

    for i = 1, #self.featuredProducts do
        local product = self.featuredProducts[i].product
        product:Refresh()
    end

    for i = 1, #self.limitedTimedOfferProducts do
        local product = self.limitedTimedOfferProducts[i].product
        product:Refresh()
    end

    for i = 1, #self.dlcProducts do
        local product = self.dlcProducts[i].product
        product:Refresh()
    end

    if self.bundleContentFragment:IsShowing() then
        self.bundleContentFragment:RefreshProducts()
    end
end

function Market:RestoreActionLayerForTutorial()
    PushActionLayerByName(GetString(SI_KEYBINDINGS_LAYER_USER_INTERFACE_SHORTCUTS))
end

function Market:RemoveActionLayerForTutorial()
    -- we exit the gamepad tutotial by pressing "Alt"
    RemoveActionLayerByName(GetString(SI_KEYBINDINGS_LAYER_USER_INTERFACE_SHORTCUTS))
end

function Market:ResetSearch()
    self.searchBox:SetText("")
end

function Market:EndCurrentPreview()
    ZO_Market_Shared.EndCurrentPreview(self)
    self:SetCurrentMultiVariationPreviewProduct(nil)
end

function Market:SetCurrentMultiVariationPreviewProduct(marketProduct)
    self.currentMultiVariationPreviewProduct = marketProduct

    local hideMultiVariationControls = marketProduct == nil
    self.previewVariationLeftArrow:SetHidden(hideMultiVariationControls)
    self.previewVariationRightArrow:SetHidden(hideMultiVariationControls)
    self.variationLabel:SetHidden(hideMultiVariationControls)

    if marketProduct then
        self.variationLabel:SetText(marketProduct:GetPreviewVariationDisplayName())
    end
end

function Market:CyclePreviewVariations(direction)
    if self.currentMultiVariationPreviewProduct then
        if direction == ZO_MARKET_PREVIEW_DIRECTION_PREVIOUS then
            self.currentMultiVariationPreviewProduct:PreviewPreviousVariation()
        else
            self.currentMultiVariationPreviewProduct:PreviewNextVariation()
        end

        self.variationLabel:SetText(self.currentMultiVariationPreviewProduct:GetPreviewVariationDisplayName())
        self:SetCanBeginPreview(false, GetFrameTimeSeconds())
    end
end

--
--[[ XML Handlers ]]--
--

function ZO_Market_OnInitialize(self)
    MARKET = Market:New(self)
    SYSTEMS:RegisterKeyboardObject(ZO_MARKET_NAME, MARKET)
end

function ZO_Market_BeginSearch(editBox)
    editBox:TakeFocus()
end

function ZO_Market_EndSearch(editBox)
    editBox:LoseFocus()
end

function ZO_Market_OnSearchTextChanged(editBox)
    MARKET:SearchStart(editBox:GetText())
end

function ZO_Market_OnSearchEnterKeyPressed(editBox)
    MARKET:SearchStart(editBox:GetText())
    editBox:LoseFocus()
end

function ZO_MarketCurrency_OnMouseEnter(control, currencyType)
    InitializeTooltip(InformationTooltip, control, BOTTOM, 0, -2)

    local currencyTooltip
    if currencyType == MKCT_CROWNS then
        currencyTooltip = GetString(SI_MARKET_CROWNS_TOOLTIP)
    elseif currencyType == MKCT_CROWN_GEMS then
        currencyTooltip = GetString(SI_MARKET_CROWN_GEMS_TOOLTIP)
    end

    SetTooltipText(InformationTooltip, currencyTooltip)
end

function ZO_MarketCurrency_OnMouseExit(control)
    ClearTooltip(InformationTooltip)
end

function ZO_MarketCurrencyBuyCrowns_OnClicked(control)
    OnMarketPurchaseMoreCrowns()
    ZO_Dialogs_ShowDialog("CONFIRM_OPEN_URL_BY_TYPE", ZO_BUY_CROWNS_URL_TYPE, ZO_BUY_CROWNS_FRONT_FACING_ADDRESS)
end

function ZO_MarketCurrencyBuySubscription_OnClicked(control)
    ZO_Dialogs_ShowDialog("CONFIRM_OPEN_URL_BY_TYPE", ZO_BUY_SUBSCRIPTION_URL_TYPE, ZO_BUY_SUBSCRIPTION_FRONT_FACING_ADDRESS)
end

function ZO_Market_PreviewArrowOnMouseClicked(control, direction)
    if MARKET:GetCanBeginPreview() then
        MARKET:CyclePreviewVariations(direction)
    end
end

function ZO_MarketContentFragmentBack_OnMouseUp(self, upInside)
    if upInside then
        PlaySound(SOUNDS.NEGATIVE_CLICK)
        MARKET:ShowMarket(true)
    end
end
