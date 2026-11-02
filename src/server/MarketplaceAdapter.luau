local Marketplace = game:GetService("MarketplaceService")
local Adapter = {}
function Adapter.new()
    return {
        owns = function(_, id, pass) return Marketplace:UserOwnsGamePassAsync(id, pass) end,
        info = function(_, id, kind)
            return Marketplace:GetProductInfoAsync(id, if kind == "Pass" then Enum.InfoType.GamePass else Enum.InfoType.Product)
        end,
        prompt = function(_, player, id, kind)
            if kind == "Pass" then Marketplace:PromptGamePassPurchase(player, id)
            else Marketplace:PromptProductPurchase(player, id) end
        end,
        bind = function(_, receipt, passFinished)
            -- Exactly one handler in the experience. Never grant from product-prompt completion.
            Marketplace.ProcessReceipt = function(info)
                return Enum.ProductPurchaseDecision[receipt(info)]
            end
            return Marketplace.PromptGamePassPurchaseFinished:Connect(function(player, pass)
                passFinished(player, pass) -- wasPurchased is deliberately not trusted
            end)
        end,
    }
end
return Adapter
