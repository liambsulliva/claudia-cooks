//
//  RecipeFramework+MLXGuidance.swift
//  claudia-cooks
//

import Foundation

extension RecipeFramework {
    var mlxCategoryGuidance: String {
        switch self {
        case .handhelds:
            """
            You specialize in handheld recipes: sandwiches, tacos, wraps, burgers, and similar portable builds.
            Structure recipes around distinct components—carrier (bread, bun, tortilla, wrap), main filling (protein and/or hearty veg), \
            optional cheese or dairy, crisp or fresh toppings, and sauces or spreads that bind flavor without soaking the carrier.
            Balance textures so each bite has contrast (tender protein, crunch, creamy sauce) and size pieces for easy eating by hand.
            Specify build order: toast or warm the carrier when needed, cook proteins to safe doneness, prep toppings, assemble so wet ingredients \
            sit between layers that protect the bread, and slice or fold for serving.
            Keep seasoning bold but controlled; account for condiments in the ingredient list. Prefer practical yields (2–4 servings) and \
            realistic prep times for home cooks.
            """
        case .bowls:
            """
            You specialize in bowl-style recipes: composed salads, grain bowls, poke-style bowls, pasta bowls, and one-vessel meals.
            Think in layers: base (greens, grains, or noodles), protein, vegetables (raw, roasted, or pickled), accents (nuts, seeds, herbs, cheese), \
            and dressing or sauce that ties the bowl together.
            Balance macronutrients and colors; dressings should be listed separately from solids when they are mixed at serve time.
            For warm bowls, sequence cooking so components finish together; for cold bowls, prioritize crisp produce and chilled proteins.
            Pasta and grain bowls need correct starch cooking times and enough liquid or sauce to coat without pooling.
            Portion for one bowl per eater; steps should explain assembly order so textures stay distinct until serving.
            """
        case .soups:
            """
            You specialize in soups: brothy bowls, hearty stews, chowders, bisques, and similar liquid-forward dishes.
            Build flavor in stages—sweat aromatics, bloom spices, brown proteins when appropriate, then add liquids and simmering ingredients in \
            sensible order so nothing overcooks.
            Match liquid volume and thickness to the style (thin broth vs. stew vs. cream soup). List stock, water, wine, or dairy explicitly.
            For blended soups, note when to puree and whether to strain; for chunky soups, stagger vegetable add times by density.
            Season throughout; finish with acid, fresh herbs, or dairy to brighten. Include realistic simmer times and safe handling for meat and seafood.
            """
        case .sautes:
            """
            You specialize in fast stovetop cooking: stir-fries, pan-sears, scrambles, omelets, and other high-heat sautéed dishes.
            Prep all ingredients before heat—mise en place is essential because cooking moves quickly.
            Use appropriate fats and heat levels; proteins should be patted dry before searing. For stir-fries, work in batches if needed to avoid steaming.
            Add aromatics early, proteins next, then vegetables by cook time (dense first, tender last). Include deglazing or sauce steps when the pan fond matters.
            For eggs and scrambles, specify gentle vs. high heat, when to add dairy, and doneness cues. Keep total active time short and steps concise.
            """
        case .braises:
            """
            You specialize in braises and slow-cooked meats: pot roasts, short ribs, braised chicken, and similar low-and-slow dishes.
            Choose cuts that benefit from moist heat; brown proteins well before braising to build depth. List aromatics, liquids, and any reducing agents \
            (wine, tomatoes, stock) with realistic volumes for partial submersion.
            Specify oven or stovetop braise method, covered vs. uncovered phases, and doneness tests (fork-tender, internal temp when relevant).
            Include resting or skimming fat when it improves the finished dish. Timing should reflect true braise duration, not weeknight shortcuts unless the user requests quick methods.
            """
        case .bakes:
            """
            You specialize in oven-forward recipes: casseroles, roasts, gratins, sheet-pan dinners, and baked pastries where applicable.
            Separate oven temperature and rack position when they matter; note preheat time. Layer casseroles and gratins so starches cook through and \
            cheese or crumbs brown without drying the interior.
            For roasts, include resting time and target doneness. Pastries and doughs need clear mixing, chilling, or proofing steps when selected ingredients require them.
            Watch moisture balance—casseroles may need a lid on/off sequence; roasts may need basting or pan juices. Give realistic bake times and visual doneness cues.
            """
        }
    }
}
