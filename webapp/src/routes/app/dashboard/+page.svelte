<script lang="ts">
  import wallet from '$lib/stores/wallet/wallet.store';
  import guardConnected from '$lib/utils/guard-connected';

  $: userId = $wallet.beamsUserId;

  $: {
    $wallet.connected;
    guardConnected();
  }

</script>

<svelte:head>
  <title>Dashboard | Beams</title>
  <meta name="description" content="Beams Dashboard" />
</svelte:head>

<div class="dashboard">
  <h1>Dashboard</h1>
  
  <div class="sections">
   
    
  </div>
</div>

<style>

  .sections {
    margin-top: 4rem;
    display: flex;
    flex-direction: column;
    gap: 4rem;
  }
</style>
