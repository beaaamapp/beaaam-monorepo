<script>
    // @ts-ignore
    import LpHeader from './components/lp-header.svelte';
    import { onMount } from 'svelte';
    import Beaaam from '$lib/images/beaaam.jpg';
    onMount(() => {

    });
  </script>
  
  <svelte:head>
    <title>Beaam • Beaaam your tokens </title>
    <meta
      name="description"
      content="Beaaam allows you to stream money without any platform fees."
    />
  </svelte:head>
  
  <LpHeader />
  <div id="lp">
    <div id="wrapper">
      <section id="hero">
        <img width="512" height="512" src={Beaaam} alt="beaaam logo" />
        <div id="title">
          <h1>Beaaaaaaam</h1>
        </div>
      
      </section>
      <section id="main-features">
       
        
      </section>
      <section>
        <section />
      
      </section>
     
      
      
    </div>
  </div>
  
  <style>
    #lp {
      --spacing-xs: 0.5rem;
      --spacing-s: 1rem;
      --spacing-m: 1.5rem;
      --spacing-l: 3rem;
      --spacing-xl: 6rem;
  
      --border-radius-pointy: 2rem 0 2rem 2rem;
      --border-radius-pointy-inner: 1rem 0 1rem 1rem;
  
      --font-serif: 'Redaction 50';
  
      --font-size-s: 1rem;
      --font-size-m: 1.5rem;
      --font-size-l: 2.5rem;
      --font-size-xl: 3rem;
    }
  
    @keyframes intro {
      0% {
        opacity: 0;
        transform: translateY(2rem);
      }
      100% {
        opacity: 1;
        transform: translateY(0);
      }
    }
  
    .nudge {
      font-size: inherit;
      letter-spacing: 0.18em;
    }
  
    h1,
    h2,
    h3 {
      color: var(--color-foreground);
      font-weight: normal;
    }
  
    h1 {
      font-size: var(--font-size-xl);
      font-family: var(--font-serif);
      color: var(--color-primary);
    }
  
    h2 {
      font-size: var(--font-size-l);
      font-family: var(--font-serif);
      line-height: 2.5rem;
    }
  
    h3 {
      font-size: var(--font-size-m);
      font-family: var(--font-serif);
    }
  
    section {
      position: relative;
    }
  
    .centered {
      text-align: center;
      display: flex;
      flex-direction: column;
      align-items: center;
    }
  
    .text-container {
      display: flex;
      flex-direction: column;
      gap: 1rem;
    }
  
    #wrapper {
      max-width: 80rem;
      width: 100vw;
      margin: 0 auto;
      padding: 1rem;
      padding-top: 6rem;
      display: flex;
      flex-direction: column;
      gap: var(--spacing-m);
      align-items: center;
    }
  
    #wrapper > * {
      width: 100%;
    }
  
    img.elevated {
      box-shadow: 0.5rem 0.5rem 0px var(--color-foreground);
      border-radius: 1rem 0 1rem 1rem;
      border: 1px solid var(--color-foreground);
    }
  
    #hero {
      display: flex;
      flex-direction: column;
      align-items: center;
      text-align: center;
      padding: 2rem 0.5rem 2rem 0.5rem;
      z-index: 10;
    }
  
   
  
    #main-features {
      display: flex;
      flex-direction: column-reverse;
      gap: 2rem;
    }
  
  
  
    @media (max-width: 768px) {
      h1 {
        font-size: var(--font-size-l);
      }
  
      h2 {
        font-size: var(--font-size-m);
        line-height: 1.5rem;
      }
  
     
  
     
    }
  
    @keyframes rotate {
      0% {
        transform: rotate(0deg);
      }
      100% {
        transform: rotate(360deg);
      }
    }
  

  
    @keyframes hover {
      0% {
        transform: translateY(0);
      }
      50% {
        transform: translateY(10%);
      }
      100% {
        transform: translateY(0);
      }
    }
  </style>
  