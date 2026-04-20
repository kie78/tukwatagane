# Tukwatagane — User Operations Flowchart

```mermaid
flowchart TD
    %% ─── APP LAUNCH ───────────────────────────────────────
    START([App Launch]) --> AUTH{Logged in?}
    AUTH -- No --> LOGIN[Login Screen]
    AUTH -- Yes --> BROWSE

    %% ─── AUTH FLOW ────────────────────────────────────────
    LOGIN -- Submit credentials --> LOGIN_OK{Success?}
    LOGIN_OK -- Yes --> BROWSE[Browse Screen]
    LOGIN_OK -- No --> LOGIN
    LOGIN -- Forgot password --> FORGOT[Forgot Password]
    FORGOT -- Reset sent --> LOGIN
    LOGIN -- No account --> SIGNUP[Sign Up Screen]
    SIGNUP -- Submit --> VERIFY[Account Auth\nEmail Verification]
    VERIFY -- Verified --> BROWSE
    SIGNUP -- Already have account --> LOGIN

    %% ─── BOTTOM NAV ───────────────────────────────────────
    BROWSE <-->|Bottom Nav| SEARCH[Search Screen]
    BROWSE <-->|Bottom Nav| SELL[Sell Screen]
    BROWSE <-->|Bottom Nav| CHATLIST[Chat Screen\nConversation List]
    BROWSE <-->|Bottom Nav| ACCOUNT[Account Screen]

    %% ─── BROWSE ───────────────────────────────────────────
    BROWSE -- Tap listing --> PRODUCT[Product Details]
    BROWSE -- Tap seller avatar --> VENDOR[Vendor Profile]
    BROWSE -- Bookmark icon → AppBar --> SAVED[Saved Items]
    BROWSE -- Tap own avatar → AppBar --> USERPROFILE[User Profile]
    BROWSE -- Contact seller on card --> INBOX

    %% ─── SEARCH ───────────────────────────────────────────
    SEARCH -- Submit query --> RESULTS[Search Results]
    SEARCH -- Tap category --> CATLIST[Category Listings]
    SEARCH -- Bookmark icon --> SAVED
    RESULTS -- Tap listing --> PRODUCT
    RESULTS -- Map pin tap --> PRODUCT
    CATLIST -- Tap listing --> PRODUCT
    CATLIST -- Map pin tap --> PRODUCT

    %% ─── SELL ─────────────────────────────────────────────
    SELL -- Post listing --> BROWSE
    SELL -- Bookmark icon --> SAVED

    %% ─── PRODUCT DETAILS ──────────────────────────────────
    PRODUCT -- Contact seller --> INBOX[Inbox\nConversation Screen]
    PRODUCT -- Tap seller name/avatar --> VENDOR

    %% ─── VENDOR PROFILE ───────────────────────────────────
    VENDOR -- Message vendor --> INBOX
    VENDOR -- Tap vendor listing --> PRODUCT

    %% ─── CHAT / INBOX ─────────────────────────────────────
    CHATLIST -- Tap conversation --> INBOX
    INBOX -- Tap counterpart header --> VENDOR
    INBOX -- Tap product reference in chat --> PRODUCT

    %% ─── SAVED ────────────────────────────────────────────
    SAVED -- Tap listing --> PRODUCT
    SAVED -- Tap saved conversation --> INBOX

    %% ─── ACCOUNT ──────────────────────────────────────────
    ACCOUNT -- Profile --> USERPROFILE[User Profile]
    ACCOUNT -- My Listings --> MYLISTINGS[My Listings]
    ACCOUNT -- Bookmarks --> SAVED
    ACCOUNT -- Logout --> LOGIN

    %% ─── USER PROFILE ─────────────────────────────────────
    USERPROFILE -- Bookmarks icon --> SAVED

    %% ─── MY LISTINGS ──────────────────────────────────────
    MYLISTINGS -- Edit listing --> SELL
    MYLISTINGS -- Bookmarks icon --> SAVED

    %% ─── STYLES ───────────────────────────────────────────
    classDef auth    fill:#FFF3CD,stroke:#F0AD4E,color:#333
    classDef nav     fill:#D1ECF1,stroke:#17A2B8,color:#333
    classDef detail  fill:#F8D7DA,stroke:#DC3545,color:#333
    classDef util    fill:#D4EDDA,stroke:#28A745,color:#333

    class LOGIN,SIGNUP,VERIFY,FORGOT auth
    class BROWSE,SEARCH,SELL,CHATLIST,ACCOUNT nav
    class PRODUCT,VENDOR,RESULTS,CATLIST,INBOX detail
    class SAVED,USERPROFILE,MYLISTINGS util
```

## Legend

| Color | Group | Screens |
|---|---|---|
| Yellow | Auth flow | Login, Sign Up, Account Auth (email verify), Forgot Password |
| Blue | Bottom Nav tabs | Browse, Search, Sell, Chat List, Account |
| Red | Detail screens | Product Details, Vendor Profile, Search Results, Category Listings, Inbox |
| Green | Utility screens | Saved Items, User Profile, My Listings |

## Notes

- **`ChatScreen`** (`chat.dart`) = conversation *list*; **`InboxScreen`** (`inbox.dart`) = individual *conversation*
- **`SellScreen`** doubles as an edit screen — `MyListings` opens it pre-filled when editing a listing
- The bookmark shortcut to `Saved` is present on many screens (Browse, Search, Chat, Sell, CategoryListings, etc.) — collapsed in the diagram for clarity

---

## Simplified Flow

![Simplified user flows](assets/images/user_flows_simple.png)

```mermaid
flowchart TD
    START([App Launch]) --> AUTH{Logged in?}
    AUTH -- No --> LOGIN[Login\nEnter email + password]
    AUTH -- Yes --> BROWSE

    LOGIN -- Submit --> BROWSE[Browse Screen\nLanding]
    LOGIN -- No account? --> SIGNUP[Sign Up\nEnter name, email, password]
    SIGNUP -- Submit --> VERIFY[Verify Email]
    VERIFY -- Confirmed --> BROWSE

    BROWSE -- Tap listing --> PRODUCT[Product Details\nView item info & price]
    BROWSE -- Search tab --> SEARCH[Search\nQuery or browse by category]
    BROWSE -- Sell tab --> SELL[Create Listing\nTitle, price, photo, location]
    BROWSE -- Account tab --> ACCOUNT[Account]

    SEARCH -- Results --> PRODUCT

    PRODUCT -- Contact seller --> MSG[Messaging\nReal-time conversation]
    PRODUCT -- Tap seller --> VENDOR[Vendor Profile\nSeller info & listings]
    VENDOR -- Message --> MSG

    SELL -- Submit --> BROWSE

    ACCOUNT -- My Listings --> MYLISTINGS[My Listings\nManage your items]
    ACCOUNT -- Logout --> LOGIN

    classDef auth   fill:#FFF3CD,stroke:#F0AD4E,color:#333
    classDef nav    fill:#D1ECF1,stroke:#17A2B8,color:#333
    classDef detail fill:#F8D7DA,stroke:#DC3545,color:#333
    classDef util   fill:#D4EDDA,stroke:#28A745,color:#333

    class LOGIN,SIGNUP,VERIFY auth
    class BROWSE,SEARCH,SELL,ACCOUNT nav
    class PRODUCT,VENDOR,MSG detail
    class MYLISTINGS util
```
