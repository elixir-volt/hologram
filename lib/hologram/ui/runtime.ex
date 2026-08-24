defmodule Hologram.UI.Runtime do
  use Hologram.Component
  prop :csrf_token, :string, from_context: {Hologram.Runtime, :csrf_token}
  prop :initial_page?, :boolean, from_context: {Hologram.Runtime, :initial_page?}
  prop :instance_id, :string, from_context: {Hologram.Runtime, :instance_id}
  prop :page_bundle_path, :string, from_context: {Hologram.Runtime, :page_bundle_path}
  prop :page_mounted?, :boolean, from_context: {Hologram.Runtime, :page_mounted?}
  prop :runtime_bundle_path, :string, from_context: {Hologram.Runtime, :runtime_bundle_path}

  @impl Component
  def template do
    ~HOLO"""
    {%if @initial_page? && !@page_mounted?}
      <script>
        globalThis.Hologram ??= \{\};
        globalThis.Hologram._pendingJsInteropActions = [];
        globalThis.Hologram.assetManifest = $ASSET_MANIFEST_JS_PLACEHOLDER;
        globalThis.Hologram.csrfToken = "{@csrf_token}";
        globalThis.Hologram.instanceId = "{@instance_id}";

        globalThis.Hologram.dispatchAction = function(actionName, target, params) \{
          globalThis.Hologram._pendingJsInteropActions.push([actionName, target, params]);
        \}
      </script>
    {/if}

    {%if @initial_page? && !@page_mounted?}
      <script>
        {%raw}
          globalThis.Hologram.pageMountData = (deps) => {
            const Type = deps.Type;
            
            return {
              componentRegistry: $COMPONENT_REGISTRY_JS_PLACEHOLDER,
              pageModule: $PAGE_MODULE_JS_PLACEHOLDER,
              pageParams: $PAGE_PARAMS_JS_PLACEHOLDER,
              selfEchoes: $SELF_ECHOES_JS_PLACEHOLDER,
              subReceiptAdds: $SUB_RECEIPT_ADDS_JS_PLACEHOLDER,
              subReceiptDrops: $SUB_RECEIPT_DROPS_JS_PLACEHOLDER
            };
          };
        {/raw}
      </script>
    {/if}

    {%if @initial_page? && !@page_mounted?}
      <script type="module" async src={@runtime_bundle_path}></script>
    {/if}

    {%if !@page_mounted?}
      <script type="module" async src={@page_bundle_path}></script>
    {/if}
    """
  end
end
