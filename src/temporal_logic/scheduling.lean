
import .lemmas
import .spec

import data.set.basic

import util.data.minimum
import util.data.ordering
import util.data.order
import util.function
import util.logic
import tactic.norm_num

open temporal function predicate nat set

local infix ` ≃ `:75 := v_eq
local prefix `♯ `:0 := cast (by simp)
universes u v

namespace temporal
namespace scheduling
section scheduling

local attribute [instance, priority 0] classical.prop_decidable
local attribute [-simp] add_comm

parameter {evt : Type u}
parameter Γ : cpred
parameter r : tvar (set evt)
parameter Hr : Γ ⊢ ◻-(r ≃ (∅ : set evt))
-- parameter [nonempty evt]

abbreviation SCHED  (s : tvar evt) :=
◻(s ∊ r) ⋀
∀∀ (e : evt),
  ◻◇(↑e ∊ r) ⟶
  ◻◇(s ≃ ↑e ⋀ ↑e ∊ r)

section implementation

parameters (f : ℕ → evt) (Hinj : surjective f)
parameter p : tvar (ℕ → evt)
parameter cur : tvar ℕ
/- consider making select into a state variable instead of a definition -/
variable select : tvar evt

infixl ` |+| `:80 := lifted₂ has_add.add
infixl ` |-| `:80 := lifted₂ has_sub.sub

noncomputable def next_p (p : ℕ → evt) (r' : set evt) (i : ℕ) : ordering → evt
 | ordering.gt := p i
 | ordering.eq := p (↓ i : ℕ, p i ∈ r')
 | ordering.lt :=
   if (↓ i : ℕ, p i ∈ r') ≤ i
          then p (i + 1)
          else p i

noncomputable def next' (r' : set evt) : ℕ × (ℕ → evt) → ℕ × (ℕ → evt)
 | (cur,p) :=
let min := ↓ i : ℕ, p i ∈ r',
    cur' := max min $ cur+1,
    p' : ℕ → evt := λ i : ℕ,
          next_p p r' i (cmp i cur')
in
(cur',p')

section

noncomputable def next : tvar $ ℕ × (ℕ → evt) → ℕ × (ℕ → evt) :=
⟪ ℕ, next' ⟫ (⊙r)
end

@[simp]
lemma next_def (cur cur' : ℕ) (p p' : ℕ → evt) (σ : ℕ)
: (cur', p') = (σ ⊨ next) (cur, p) ↔
   cur' = max (↓ (i : ℕ), p i ∈ succ σ ⊨ r) (cur + 1) ∧
∀ i, p' i =
          next_p p
            (succ σ ⊨ r) i
            (cmp i cur') :=
by { repeat { simp [next,next'] <|> unfold_coes },
     apply and_congr_right,
     intro,
     split, { introv h, subst cur', simp [h], },
     { intro, apply funext,
       intro, subst cur', solve_by_elim } }

section
parameter f

@[predicate]
noncomputable def cur₀ : tvar ℕ :=
[| r , ↓ i : ℕ, f i ∈ r |]

-- noncomputable abbreviation select₀ : tvar evt :=
-- [| r , f (↓ i : ℕ, f i ∈ r) |]

-- noncomputable def nxt_select : tvar (evt → evt) :=
-- [| p , λ (p' : ℕ → ℕ) (r' : set evt) (e : evt),
--   inv q $ ↓ i : ℕ, inv q i ∈ r' |] (⊙q) (⊙r)

end

noncomputable def Spec :=
⦃cur,p⦄ ≃ ⦃cur₀,f⦄ ⋀ ◻(⊙⦃cur,p⦄ ≃ next ⦃cur,p⦄)

parameter Hq : Γ ⊢ Spec

@[predicate]
def select : tvar evt :=
p cur

-- noncomputable def select_Spec :=
-- select ≃ select₀ ⋀ ◻(⊙select ≃ nxt_select select)

-- variables Hs : Γ ⊢ select_Spec select

section q_injective

lemma next_rec (P : ℕ → Prop) (cur cur') (p p' : ℕ → evt) (r' : set evt)
  {i : ℕ} {e : evt}
  (h : p i = e)
  (Hcur' : cur' = max (↓ (i : ℕ), p i ∈ r') (cur + 1))
  (Hq' : ∀ (i : ℕ), p' i =
       next_p p r' i (cmp i cur'))
  (Hcase_lt : (i < ↓ (i : ℕ), p i ∈ r') ∨ (↓ (i : ℕ), p i ∈ r') < i ∧ ¬i ≤ cur' →
               next_p p r' i (cmp i cur') = e →
               P i)
  (Hcase_eq : (i = ↓ (i : ℕ), p i ∈ r') →
               next_p p r' cur' (cmp cur' cur') = e →
               P cur')
  (Hcase_gt : (↓ (i : ℕ), p i ∈ r') < i →
               next_p p r' (i - 1) (cmp (i - 1) cur') = e →
               P (i - 1))
: (∃ j, p' j = e ∧ P j) :=
begin
  ordering_cases cmp i (↓ i, p i ∈ r'),
  { existsi i, rw Hq',
    suffices : cmp i cur' = ordering.lt,
    { rw [this,next_p,if_neg,h] at *,
      { existsi [rfl], apply_assumption,
        left, solve_by_elim, refl, },
      all_goals { apply not_le_of_gt h_1 }, },
    rw [cmp,cmp_using_eq_lt,Hcur'],
    apply lt_max_of_lt_left _ h_1, },
  { existsi cur', rw Hq',
    have : cmp cur' cur' = ordering.eq,
    { rw [cmp_eq_eq], },
    rw and_iff_imp, intro, solve_by_elim,
    rw [this,next_p], cc },
  by_cases h_cur : i ≤ cur',
  { existsi i - 1, rw Hq',
    have h_i_gt_0 : 0 < i,
    { apply lt_of_le_of_lt,
      apply nat.zero_le, assumption, },
    have : cmp (i - 1) cur' = ordering.lt,
    { rw [cmp,cmp_using_eq_lt],
      apply lt_of_lt_of_le _ h_cur,
      show i - 1 < i,
      { apply nat.sub_lt, assumption, norm_num }, },
    rw and_iff_imp, intro, solve_by_elim,
    rw [this,next_p,if_pos,nat.sub_add_cancel,h],
    assumption,
    rw ← add_le_to_le_sub,
    repeat { assumption }, },
  { existsi i, rw Hq',
    have : cmp i cur' = ordering.gt,
    { rw [cmp,cmp_using_eq_gt],
      apply lt_of_not_ge h_cur },
    rw and_iff_imp, intro, apply_assumption,
    right, tauto, solve_by_elim,
    rw [this,next_p,h] at *, }
end

include Hq Hinj

/- TODO: split into lemmas -/
lemma q_injective
: Γ ⊢ ◻(⟨ surjective ⟩ ! p) :=
begin [temporal]
  cases Hq with Hq Hq',
  t_induction!,
  { explicit' with Hq
    { cases_matching* _ ∧ _, subst p, solve_by_elim, } },
  { henceforth at Hq',
    explicit' with ih Hq'
    { simp_intros e, cases ih e with i h,
      cases Hq' with Hcur' Hq',
      ordering_cases cmp i (↓ i, p i ∈ r'),
      { existsi i, rw Hq',
        suffices : cmp i cur' = ordering.lt,
        { rw [this,next_p,if_neg,h],
          apply not_le_of_gt h_1, },
        rw [cmp,cmp_using_eq_lt,Hcur'],
        apply lt_max_of_lt_left _ h_1, },
      { existsi cur', rw Hq',
        have : cmp cur' cur' = ordering.eq,
        { rw [cmp_eq_eq], },
        rw [this,next_p], cc },
      by_cases h_cur : i ≤ cur',
      { existsi i - 1, rw Hq',
        have h_i_gt_0 : 0 < i,
        { apply lt_of_le_of_lt,
          apply nat.zero_le, assumption, },
        have : cmp (i - 1) cur' = ordering.lt,
        { rw [cmp,cmp_using_eq_lt],
          apply lt_of_lt_of_le _ h_cur,
          show i - 1 < i,
          { apply nat.sub_lt, assumption, norm_num }, },
        rw [this,next_p,if_pos,nat.sub_add_cancel,h],
        assumption,
        rw ← add_le_to_le_sub,
        repeat { assumption }, },
      { existsi i, rw Hq',
        have : cmp i cur' = ordering.gt,
        { rw [cmp,cmp_using_eq_gt],
          apply lt_of_not_ge h_cur },
        rw [this,next_p,h], } } },
end

end q_injective

section

-- include Hq
-- lemma select_eq_inv_q_cur'
-- : Γ ⊢ select_Spec select' :=
-- begin [temporal]
--   cases Hq with Hq₀ Hq,
--   split,
--   explicit' { cc },
--   henceforth! at ⊢ Hq,
--   explicit' [nxt_select]
--   { cases Hq with Hcur Hq,
--     rw [inv_eq _ _ _],
--     rw [Hq,← Hcur],
--     ordering_cases cmp (↓ (i : ℕ), inv q i ∈ r') (q (inv q (↓ (i : ℕ), inv q i ∈ r')))
--     ; simp [next_p],
--     ite_cases,
--     { exfalso, apply h_1, clear h_1,
--       rw Hcur, rw le_max_iff_le_or_le, left,
--        } }
--   { verbose := tt }
-- end

-- include Hs Hinj

-- lemma select_eq_inv_q_cur
-- : Γ ⊢ ◻[| q cur select, select = inv q cur |] :=
-- begin [temporal]
--   have Hinj_q := temporal.scheduling.q_injective,
--   have Hinj_q' := henceforth_next _ _ Hinj_q,
--   cases Hq with Hq₀ Hq,
--   cases Hs with Hs₀ Hs,
--   t_induction! using Hq Hs Hinj_q' Hinj_q,
--   explicit' { cc },
--   explicit' [nxt_select]
--   { cases Hq,
--     rw inv_eq _ _ Hinj_q',
--     rw [Hq_right],
--     ordering_cases (cmp (↓ (i : ℕ), inv q i ∈ r') (q select'))
--     ; simp [next_p],
--     ite_cases,
--     { exfalso, apply h_1, clear h_1,
--       rw le_max_iff_le_or_le, left,
--       apply le_of_eq, clear_except Hs, },
--     {  },
--     {  },
--     {  } }
-- end
-- end

open set

-- invariant
--           inv q' cur' = (↓ i, inv q' i ∈ r)
--           inv q' cur' ≤ (↓ i, inv q' i ∈ r)
--           inv q' cur' ≥ (↓ i, inv q' i ∈ r)

section
include Hr Hq Hinj
lemma valid_indices_ne_empty
: Γ ⊢ ◻([| p, λ r : set evt, { i : ℕ | p i ∈ r } ≠ ∅ |] (⊙r)) :=
begin [temporal]
  have Hsur := temporal.scheduling.q_injective,
  replace Hr := henceforth_next _ _ Hr,
  henceforth! at Hr Hsur ⊢,
  explicit' with Hr Hsur
  { rw not_eq_empty_iff_exists at *,
    cases Hr with i Hr,
    existsi inv p i,
    change _ ∈ r',
    rw [inv_is_right_inverse_of_surjective Hsur],
    assumption, }
end
end

noncomputable def rank (e : evt) : tvar ℕ :=
[| p, ↓ i, p i = e |]

include Hr Hq Hinj
lemma sched_inv
: Γ ⊢ ◻(select ∊ r) :=
begin [temporal]
  have Hq_inj := temporal.scheduling.q_injective,
  have hJ := temporal.scheduling.valid_indices_ne_empty,
  cases Hq with Hq₀ Hq,
  have Hq_inj' := henceforth_next _ _ Hq_inj,
  t_induction!,
  henceforth! at Hr Hq_inj,
  { explicit' [select,cur₀] with Hq₀ Hr Hq_inj
    { change cur ∈ { i | p i ∈ r },
      rw [Hq₀.left,Hq₀.right],
      apply minimum_mem,
      intro, apply Hr,
      rw eq_empty_iff_forall_not_mem at *,
      intro x, specialize a (inv p x),
      -- apply Hr,
      intro, apply a,
      show f (inv p x) ∈ r,
      cases Hq₀, subst p,
      rw [inv_is_right_inverse_of_surjective Hq_inj],
      assumption } },
  henceforth! at Hr Hq_inj' Hq_inj Hq hJ,
  explicit' with Hq hJ
  { cases Hq with Hq Hq',
    rw Hq',
    have : cmp cur' cur' = ordering.eq,
    { rw cmp_eq_eq },
    rw [this,next_p],
    change (↓ (i : ℕ), p i ∈ r') ∈ { i | p i ∈ r' },
    apply minimum_mem,
    assumption },
end

lemma cur_lt_cur'
: Γ ⊢ ◻(cur ≺ ⊙cur) :=
begin [temporal]
  cases Hq with Hq₀ Hq,
  henceforth! at Hq ⊢,
  explicit' with Hq
  { simp [Hq],
    apply lt_max_of_lt_right,
    apply lt_add_one, }
end


section sched_queue_safety
variables
  (q₀ : ℕ)
  (e : evt)
  (Hprev : Γ ⊢ rank e |+| (rank e |-| cur) ≃ ↑q₀)
  (H₂ : Γ ⊢ ⊙(-(⟨λ (i : ℕ), (i ⊨ rank e) + ((i ⊨ rank e) - (i ⊨ cur))⟩ ≺≺ q₀) ⋀
                   -(select ≃ e)))
  (Hdec : Γ ⊢ cur ≺ ⊙cur)
  (Hsurj : Γ ⊢ ⊙( ⟨ surjective ⟩ ! p ))
  (this : Γ ⊢ ⊙rank e ≼ rank e ⋁ ⊙(cur ≃ rank e))

omit Hq
include Hdec Hprev Hsurj H₂ this
lemma non_dec_po
: Γ ⊢ ⊙(rank e |+| (rank e |-| cur) ≃ ↑q₀) :=
begin [temporal]
  explicit' [next,next',select,rank]
    with Hprev this H₂ Hdec Hsurj
  { subst q₀,
    cases this with this this,
    cases lt_or_eq_of_le this,
    { exfalso, apply H₂.left,
      change _ + _ < _ + _,
      apply lt_of_lt_of_le,
      { apply add_lt_add_right h, },
      apply add_le_add_left,
      transitivity,
      { apply nat.sub_le_sub_left,
      apply le_of_lt Hdec, },
      { apply nat.sub_le_sub_right this, } },
    { simp [h],
      let rank := (↓ (i : ℕ), p i = e),
      have : rank - cur' ≤ rank - cur,
      { apply nat.sub_le_sub_left, apply le_of_lt Hdec },
      cases lt_or_eq_of_le this,
      { exfalso, apply H₂.left,
        change _ + _ < _ + _, simp [h,h_1], },
      assumption },
    replace H₂ := H₂.right, rw this at H₂,
    have H₀ : { i : ℕ | p' i = e } ≠ ∅,
    { apply ne_empty_of_mem _,
      exact (inv p' e),
      change p' (inv p' e) = e,
      apply inv_is_right_inverse_of_surjective Hsurj, },
    have H₃ := minimum_mem H₀,
    cases H₂ H₃, },
end

end sched_queue_safety

lemma subsumes_requested (e : evt)
: Γ ⊢ ◻( select ≃ ↑e ⋀ ↑e ∊ r
             ≡ select ≃ ↑e ) :=
begin [temporal]
  have Hr' := temporal.scheduling.sched_inv,
  henceforth! at ⊢ Hr',
  explicit' [select] with Hr'
  { split,
    { simp, intros, assumption },
    { intros, cc, } },
end

-- include Hinj
/-- TODO: Pull out lemmas -/
lemma sched_queue_safety (q₀ : ℕ) (e : evt)
: Γ ⊢ ◻(rank e |+| (rank e |-| cur) ≃ ↑q₀ ⟶
    ◻(rank e |+| (rank e |-| cur) ≃ ↑q₀) ⋁
    ◇(rank e |+| (rank e |-| cur) ≺≺ ↑q₀ ⋁ select ≃ ↑e)) :=
begin [temporal]
  have hJ := temporal.scheduling.q_injective,
  have Hinc := temporal.scheduling.cur_lt_cur',
  have p_not_empty := temporal.scheduling.valid_indices_ne_empty,
  have p'_not_empty := henceforth_next _ _ p_not_empty,
  cases Hq with Hq Hq',
  henceforth!, intro H,
  rw [p_or_comm,← p_not_p_imp],
  intros H₁, simp [p_not_p_or,p_not_p_and] at H₁,
  t_induction,
  { assumption },
  { henceforth!, intro Hprev,
    have H₂ := henceforth_next _ _ H₁,
    have hJ' := henceforth_next _ _ hJ,
    henceforth at Hinc Hq' H₁ H₂ hJ hJ' p_not_empty p'_not_empty,
    apply temporal.scheduling.non_dec_po _ _ Hprev H₂ Hinc hJ',
    explicit' [next,next',select,rank] with Hq' hJ hJ' H₂
    { cases Hq' with Hcur Hq,
      replace Hq := congr_fun Hq, simp only at Hq,
      rw [or_comm,or_iff_not_imp], intro Hncur,
      have p_not_empty : { i : ℕ | p i = e } ≠ ∅,
      { rw ne_empty_iff_exists_mem, apply hJ e, },
      have p'_not_empty : { i : ℕ | p' i = e } ≠ ∅,
      { rw ne_empty_iff_exists_mem, apply hJ' e, },
      apply (le_minimum_iff_forall_le p_not_empty (↓ (i : ℕ), p' i = e)).2,
      assume j (Hj : p j = e),
      apply (minimum_le_iff_exists_le p'_not_empty j).2,
      rw ← Hcur at Hq,
      apply next_rec _ cur cur' p p' r' Hj Hcur Hq,
      { intros, refl },
      { intros h h',
        rw ← Hq at h', cases H₂.right h', },
      { intros, apply nat.sub_le, } }, },
end

/- TODO: split into lemmas -/
lemma sched_queue_liveness (q₀ : ℕ) (e : evt)
: Γ ⊢ ⊙(↑e ∊ r) ⋀ rank e |+| (rank e |-| cur) ≃ ↑q₀ ~>
  rank e |+| (rank e |-| cur) ≺≺ ↑q₀ ⋁ select ≃ ↑e ⋀ ↑e ∊ r :=
begin [temporal]
  { have Hq_inj := temporal.scheduling.q_injective,
    have Hinc := temporal.scheduling.cur_lt_cur',
    cases Hq with Hq₀ Hq,
    henceforth! at ⊢ Hq Hq_inj Hinc,
    have Hq_inj' : ⊙(⟨surjective⟩ ! p) := holds_next _ _ Hq_inj,
    simp, intros hreq hq₀,
    apply next_entails_eventually,
    explicit' [select,next,next',rank]
      with Hq hreq hq₀ Hinc  Hq_inj
    { cases Hq with Hq Hq' Hq_inj,
      replace Hq' := congr_fun Hq', simp at Hq',
      rw ← Hq at Hq',
      let rank := ↓ i, p i = e,
      have Hrank : p rank = e := _,
      let P := λ k, k + (k - cur') < q₀ ∨ k = cur',
      have rec := temporal.scheduling.next_rec P cur cur' p p' r' Hrank Hq Hq' _ _ _,
      { cases rec with k Hk, cases Hk with Hpk Hk,
        cases Hk with Hk Hk,
        { left, change _ + _ < _,
          apply @lt_of_le_of_lt _ _ _ (k + (k - cur')),
          have h : (↓ (i : ℕ), p' i = e) ≤ k, apply minimum_le, exact Hpk,
          apply add_le_add, assumption,
          apply nat.sub_le_sub_right,
          assumption, assumption, },
        { right, cc }, },
      { simp [P,rank], intros h₀ h₁,
        rw ← Hq' (↓ (i : ℕ), p i = e) at h₁,
        clear P,
        cases h₀,
        { right, clear hq₀ Hq',
          have : cur + 1 ≤ (↓ (i : ℕ), p i ∈ r'), admit,
          rw max_eq_left this at Hq, clear this,
          admit },
        { left, rw ← hq₀,
          have : ((↓ (i : ℕ), p i = e) ≥ cur'),
          { apply le_of_lt h₀.right },
          monotonicity Hinc }, },
      { intros, rw ← Hq' at a_1,
        right, refl, },
      { intros, rw ← Hq' at a_1,
        left, rw ← hq₀,
        apply lt_of_lt_of_le,
        apply add_lt_add_right,
        apply nat.sub_lt, apply lt_of_le_of_lt (nat.zero_le _) a,
        norm_num, apply nat.sub_le_sub,
        apply nat.sub_le, apply le_of_lt Hinc, },
      { have h : { i | p i = e } ≠ ∅,
        { rw ne_empty_iff_exists_mem, apply Hq_inj, },
        apply minimum_mem h, } } },
end

lemma sched_fairness (e : evt)
: Γ ⊢ ◻◇(↑e ∊ r) ⟶ ◻◇(select ≃ ↑e ⋀ ↑e ∊ r) :=
begin [temporal]
  suffices : ◻◇⊙(↑e ∊ r) ⟶ ◻◇(temporal.scheduling.select ≃ ↑e ⋀ ↑e ∊ r),
  { intro h, apply this,
    rw [← next_eventually_comm], apply henceforth_next _ _ h, },
  apply inf_often_induction' (temporal.scheduling.rank e |+| (temporal.scheduling.rank e |-| cur)) ; intro q₀,
  { rw temporal.scheduling.subsumes_requested e,
    apply temporal.scheduling.sched_queue_safety q₀ e, },
  { apply temporal.scheduling.sched_queue_liveness }
end

def correct_sched
: Γ ⊢ SCHED select :=
begin [temporal]
  split,
  { apply temporal.scheduling.sched_inv, },
  { intro, apply temporal.scheduling.sched_fairness },
end
end
end implementation

-- class schedulable (α : Sort u) :=
--   (f : α → ℕ)
--   (inj : injective f)
open encodable

example (w σ₀ : tvar ℕ)
: ⇑(to_fun_var (λ (w : tvar ℕ), w ≃ σ₀)) w = w ≃ σ₀ :=
begin
  -- rw [v_eq,to_fun_var_lift₂],
  -- dsimp,
  -- dsimp,
  -- unfold_coes,
  -- dsimp with lifted_fn,
  -- unfold_coes,
  simp! only with lifted_fn predicate,
end

lemma scheduler [encodable evt]
  (Hr : Γ ⊢ ◻-(r ≃ (∅ : set evt)))
: Γ ⊢ (∃∃ s, SCHED s) :=
begin [temporal]
  let f' : (evt → ℕ) := @encode evt _,
  let f : tvar (evt → ℕ) := f',
  have Hnemp : ∃∃ x : evt, True,
  { admit },
  nonempty evt,
  let g' : (ℕ → evt) := inv (@encode evt _),
  let g  : tvar (ℕ → evt) := g',
  let σ₀ := ⦃cur₀ r g',g⦄,
  select_witness w : w ≃ σ₀ ⋀ ◻(⊙w ≃ temporal.scheduling.next w),
  have := fwd_witness σ₀ (next r) Γ,
  cases this with cur Hcur,
  cases cur with cur q,
  existsi select p cur,
  note Hsur : surjective (inv f'),
  { apply surjective_of_has_right_inverse,
    existsi f',
    apply inv_is_left_inverse_of_injective,
    apply schedulable.inj },
  type_check @temporal.scheduling.correct_sched,
  apply temporal.scheduling.correct_sched (inv f') Hsur _,
  simp [Spec,σ₀] at ⊢ Hcur,
  exact Hcur,
end

end scheduling

section spec

variables Γ : cpred
variables {α : Type v} (m : mch α)
local notation `evt` := m.evt
variable [encodable evt]
local notation `cs` := m.cs
local notation `fs` := m.fs
local notation `p` := m.init
local notation `A` := m.A

lemma sch_intro (v : tvar α)
: Γ ⊢ m.spec v ⟶ (∃∃ sch, m.spec_sch v sch) :=
begin [temporal]
  intro h,
  let r : tvar (set (option evt)) := ⟪ ℕ, λ s s', { e | m.effect e s s' } ⟫ v ⊙v,
  have hr : ◻-(r ≃ (∅ : set (option evt))),
  { simp [mch.spec] at h,
    casesm* _ ⋀ _,
    select Hact : ◻(p_exists _),
    henceforth! at Hact ⊢,
    explicit' [r] with Hact
    { erw [← not_eq_empty_iff_exists] at Hact, exact Hact }, },
  have h' := temporal.scheduling.scheduler Γ r hr,
  cases h' with sch h',
  existsi sch,
  simp  at ⊢ h,
  casesm* _ ⋀ _,
  split!* ; try { solve_by_elim },
  { select h' : ◻(p_exists _),
    select hJ : ◻(_ ∊ _),
    henceforth! at hJ h' ⊢,
    existsi sch with hh,
    { explicit' [r] with hh hJ h'
      { subst sch, tauto } } },
  { introv, intros h₀ h₁,
    rename a_3 h₂,
    replace h₂ := h₂ x h₀ h₁,
    replace a_1 := a_1 x,
    persistent,
    have H₀ : ↑x ∊ r ≡ cs x ! v ⋀ fs x ! v ⋀ ⟦ v | A x ⟧,
    { explicit' [r]
      { simp [mch.effect,and_assoc] }, },
    have H₁ : sch ≃ ↑x ⋀ ↑x ∊ r ≡ cs x ! v ⋀ fs x ! v ⋀ (sch ≃ ↑x ⋀ ⟦ v | A x ⟧),
    { explicit' [r,mch.effect,and_assoc]
      { apply eq.to_iff, ac_refl }, },
    rw [H₁,H₀] at a_1,
    solve_by_elim, }
end

end spec
end scheduling
export scheduling (schedulable sch_intro)
end temporal
