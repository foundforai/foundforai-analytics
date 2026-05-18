defmodule PlausibleWeb.PageController do
  use PlausibleWeb, :controller
  use Plausible.Repo

  plug PlausibleWeb.RequireLoggedOutPlug

  @doc """
  Public marketing landing page for analytics.foundforai.com.
  Sets a marketing-quality title + description and embeds JSON-LD
  (SoftwareApplication + FAQPage + Organization) so AI assistants
  and search engines can describe the product accurately.
  """
  def index(conn, _params) do
    render(conn, "index.html",
      title: "Found For AI Analytics · Track how AI recommends your business",
      description:
        "Privacy-friendly web analytics that show how ChatGPT, Claude, Perplexity, and Gemini are sending traffic to your business. $49/month with a 7-day free trial. No cookies. No setup call.",
      canonical_url: "https://analytics.foundforai.com/",
      json_ld: landing_json_ld()
    )
  end

  @doc """
  Post-Stripe-checkout landing page. Users land here right after paying via a
  Stripe Payment Link. The webhook handler creates their account asynchronously
  and emails them a one-time login link, so this page just tells them what to
  expect next.
  """
  def welcome(conn, _params) do
    render(conn, "welcome.html",
      title: "Subscription started — check your email · Found For AI Analytics",
      description:
        "Your Found For AI Analytics subscription is active. We've emailed you a one-time login link.",
      canonical_url: "https://analytics.foundforai.com/welcome"
    )
  end

  defp landing_json_ld do
    %{
      "@context" => "https://schema.org",
      "@graph" => [
        %{
          "@type" => "Organization",
          "@id" => "https://foundforai.com/#org",
          "name" => "Found For AI",
          "url" => "https://foundforai.com",
          "logo" => "https://analytics.foundforai.com/images/ee/apple-touch-icon.png",
          "sameAs" => [
            "https://x.com/FoundForAI",
            "https://github.com/foundforai"
          ]
        },
        %{
          "@type" => "SoftwareApplication",
          "@id" => "https://analytics.foundforai.com/#software",
          "name" => "Found For AI Analytics",
          "applicationCategory" => "WebApplication",
          "operatingSystem" => "Web",
          "description" =>
            "Privacy-friendly web analytics that surface how AI assistants like ChatGPT, Claude, Perplexity, and Gemini recommend your business. Includes a monthly DIY AEO report.",
          "url" => "https://analytics.foundforai.com",
          "offers" => %{
            "@type" => "Offer",
            "price" => "49.00",
            "priceCurrency" => "USD",
            "priceSpecification" => %{
              "@type" => "UnitPriceSpecification",
              "price" => "49.00",
              "priceCurrency" => "USD",
              "billingDuration" => "P1M"
            }
          },
          "provider" => %{"@id" => "https://foundforai.com/#org"}
        },
        %{
          "@type" => "FAQPage",
          "@id" => "https://analytics.foundforai.com/#faq",
          "mainEntity" => [
            %{
              "@type" => "Question",
              "name" => "What's actually different from Google Analytics?",
              "acceptedAnswer" => %{
                "@type" => "Answer",
                "text" =>
                  "Three things: it's privacy-friendly so you don't need cookie banners, it surfaces AI assistant traffic (ChatGPT, Claude, Perplexity, Gemini) as a first-class source, and it ships with a monthly DIY AEO report. Google Analytics gives you a fire-hose; we give you the small set of signals that actually move the needle."
              }
            },
            %{
              "@type" => "Question",
              "name" => "Do I need to install anything complicated?",
              "acceptedAnswer" => %{
                "@type" => "Answer",
                "text" =>
                  "No. Paste one line of HTML into your head tag. We also support WordPress (plugin), Google Tag Manager (template), and NPM (for React/Next/Vue apps). Most installs take under three minutes."
              }
            },
            %{
              "@type" => "Question",
              "name" => "What's in the monthly DIY AEO report?",
              "acceptedAnswer" => %{
                "@type" => "Answer",
                "text" =>
                  "A plain-English audit of how AI assistants currently describe your business, gaps in your structured data, and the two or three highest-leverage fixes to ship this month. You implement them yourself. If you want us to do the implementation, upgrade to the Starter plan on foundforai.com."
              }
            },
            %{
              "@type" => "Question",
              "name" => "Can I cancel anytime?",
              "acceptedAnswer" => %{
                "@type" => "Answer",
                "text" =>
                  "Yes. Month-to-month, no long-term contract, cancel in one click in Stripe. If you cancel during the 7-day trial, you're never charged."
              }
            },
            %{
              "@type" => "Question",
              "name" => "Is this GDPR / CCPA compliant?",
              "acceptedAnswer" => %{
                "@type" => "Answer",
                "text" =>
                  "Yes. We don't use cookies, don't collect personal information, and don't fingerprint visitors. You don't need a cookie banner or consent prompt to run Found For AI Analytics on your site."
              }
            }
          ]
        }
      ]
    }
  end
end
