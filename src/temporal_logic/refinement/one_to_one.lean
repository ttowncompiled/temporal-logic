import .simulation

universe variables u u₀ u₁ u₂
open predicate nat

namespace temporal

namespace one_to_one
section
open fairness
parameters {α : Type u} {β : Type u₀} {γ : Type u₁ }
parameters {evt : Type u₂}
parameters {p : pred' (γ×α)} {q : pred' (γ×β)}
parameters (A : evt → act (γ×α)) (C : evt → act (γ×β))
parameters {cs₀ fs₀ : evt → pred' (γ×α)} {cs₁ fs₁ : evt → pred' (γ×β)}
parameters (J : pred' (γ×α×β))

abbreviation ae (i : evt) : event (γ×α) := ⟨cs₀ i,fs₀ i,A i⟩
abbreviation ce (i : evt) : event (γ×β) := ⟨cs₁ i,fs₁ i,C i⟩

section specs

parameters p q cs₀ fs₀ cs₁ fs₁

def SPEC₀.saf (v : tvar α) (o : tvar γ) : cpred :=
p ! ⦃ o,v ⦄ ⋀
◻(∃∃ i, ⟦ o,v | A i ⟧)

def SPEC₀ (v : tvar α) (o : tvar γ) : cpred :=
SPEC₀.saf v o ⋀
∀∀ i, sched (cs₀ i ! ⦃o,v⦄) (fs₀ i ! ⦃o,v⦄) ⟦ o,v | A i ⟧

def SPEC₁ (v : tvar β) (o : tvar γ) : cpred :=
q ! ⦃ o,v ⦄ ⋀
◻(∃∃ i, ⟦ o,v | C i ⟧) ⋀
∀∀ i, sched (cs₁ i ! ⦃o,v⦄) (fs₁ i ! ⦃o,v⦄) ⟦ o,v | C i ⟧

def SPEC₂ (v : tvar β) (o : tvar γ) (s : tvar evt) : cpred :=
q ! ⦃ o,v ⦄ ⋀
◻(∃∃ i, s ≃ ↑i ⋀ ⟦ o,v | C i ⟧) ⋀
∀∀ i, sched (cs₁ i ! ⦃o,v⦄) (fs₁ i ! ⦃o,v⦄) (s ≃ ↑i ⋀ ⟦ o,v | C i ⟧)

end specs

parameters [inhabited α] [inhabited evt]
parameter SIM₀ : ∀ v o, (o,v) ⊨ q → ∃ w, (o,w) ⊨ p ∧ (o,w,v) ⊨ J
parameter SIM
: ∀ w v o v' o' e,
  (o,w,v) ⊨ J →
  C e (o,v) (o',v') →
  ∃ w', A e (o,w) (o',w') ∧
        (o',w',v') ⊨ J

parameters (v : tvar β) (o : tvar γ) (sch : tvar evt)

variable (Γ : cpred)

parameters β γ

variable Hpo : ∀ w e,
  one_to_one_po' (SPEC₁ v o ⋀ SPEC₀.saf w o ⋀ ◻(J ! ⦃o,w,v⦄))
     (ce e) (ae e) ⦃o,v⦄ ⦃o,w⦄

parameters {β γ}

section SPEC₂
variables H : Γ ⊢ SPEC₂ v o sch

open prod temporal.prod

def Next_a : act $ (γ × evt) × α :=
λ σ σ',
∃ e, σ.1.2 = e ∧ (A e on map_left fst) σ σ'

def Next_c : act $ (γ × evt) × β :=
λ σ σ',
∃ e, σ.1.2 = e ∧ (C e on map_left fst) σ σ'

section J
def J' : pred' ((γ × evt) × α × β) :=
J ! ⟨ prod.map_left fst ⟩

def p' : pred' ((γ × evt) × α) :=
p ! ⟨ prod.map_left fst ⟩

def q' : pred' ((γ × evt) × β) :=
q ! ⟨ prod.map_left fst ⟩

end J

variable w : tvar α
open simulation function
noncomputable def Wtn := Wtn p' Next_a J' v ⦃o,sch⦄

variable valid_witness
: Γ ⊢ Wtn w

lemma abstract_sch (e : evt)
: Γ ⊢ sch ≃ e ⋀ ⟦ o,w | A e ⟧ ≡ sch ≃ e ⋀ ⟦ ⦃o,sch⦄,w | Next_a ⟧ :=
begin
  lifted_pred,
  split ; intro h ; split
  ; cases h with h₀ h₁ ; try { assumption },
  { simp [Next_a,on_fun,h₀], auto, },
  { simp [Next_a,on_fun,h₀] at h₁, auto }
end

section Simulation_POs
include SIM₀
lemma SIM₀' (v : β) (o : γ × evt)
  (h : (o, v) ⊨ q')
: (∃ (w : α), (o, w) ⊨ p' ∧ (o, w, v) ⊨ J') :=
begin
  simp [q',prod.map_left] at h,
  specialize SIM₀ v o.1 h,
  revert SIM₀, intros_mono,
  simp [J',p',map], intros,
  constructor_matching* [Exists _, _ ∧ _] ;
  tauto,
end

omit SIM₀
include SIM
lemma SIM' (w : α) (v : β) (o : γ × evt) (v' : β) (o' : γ × evt)
  (h₀ : (o, w, v) ⊨ J')
  (h₁ : Next_c (o, v) (o', v'))
: (∃ w', Next_a (o,w) (o',w') ∧ (o', w', v') ⊨ J') :=
begin
  simp [J',map] at h₀,
  simp [Next_c,on_fun] at h₁,
  specialize SIM w v o.1 v' o'.1 o.2 h₀ h₁,
  cases SIM with w' SIM,
  existsi [w'],
  simp [Next_a, J',on_fun,map,h₀],
  exact SIM,
end

include H
omit SIM
lemma H'
: Γ ⊢ simulation.SPEC₁ q' Next_c v ⦃o,sch⦄ :=
begin [temporal]
  simp [SPEC₂,simulation.SPEC₁,q'] at H ⊢,
  split, tauto,
  casesm* _ ⋀ _,
  persistent,
  select h : ◻p_exists _,
  henceforth at h ⊢,
  cases h with e h,
  explicit
  { simp [Next_c,on_fun,map_right] at a ⊢ h,
    cases h, subst e, auto },
end

include SIM₀ SIM
lemma witness_imp_SPEC₀_saf
  (h : Γ ⊢ Wtn w)
: Γ ⊢ SPEC₀.saf w o :=
begin [temporal]
  have hJ := J_inv_in_w p' q'
                        temporal.one_to_one.Next_a temporal.one_to_one.Next_c
                        temporal.one_to_one.J'
                        temporal.one_to_one.SIM₀'
                        temporal.one_to_one.SIM'
                        v ⦃o,sch⦄ Γ
                        (temporal.one_to_one.H' _ H) _ h,
  simp [SPEC₀.saf,SPEC₂,Wtn,simulation.Wtn] at h ⊢ H,
  casesm* _ ⋀ _,
  split,
  { clear SIM hJ,
    select h : w ≃ _,
    select h' : q ! _,
    rw [← pair.snd_mk sch w,h],
    explicit
    { simp [Wx₀] at ⊢ h', unfold_coes,
      simp [Wx₀_f,p',J',map],
      cases SIM₀ (σ ⊨ v) (σ ⊨ o) h',
      apply_epsilon_spec, } },
  { clear SIM₀,
    select h : ◻(_ ≃ _),
    select h' : ◻(p_exists _),
    persistent,
    henceforth at h h' ⊢ hJ,
    explicit
    { existsi σ ⊨ sch,
      simp at ⊢ h,
      repeat
      { unfold_coes at h <|>
        simp [Wf,Wf_f,J',map] at h hJ },
      simp at h h',
      simp [Next_a,on_fun,map_right] at h,
      rw [h], clear h,
      apply_epsilon_spec, } },
end

omit H
parameters p q cs₁ fs₁
include Hpo p

lemma SPEC₂_imp_SPEC₁
: (SPEC₂ v o sch) ⟹ (SPEC₁ v o) :=
begin [temporal]
  simp only [SPEC₁,SPEC₂,temporal.one_to_one.SPEC₁,temporal.one_to_one.SPEC₂],
  monotonicity, apply ctx_p_and_p_imp_p_and',
  { monotonicity, simp, intros x h₀ h₁,
    existsi x, exact h₁ },
  { intros h i h₀ h₁,
    replace h := h _ h₀ h₁,
    revert h, monotonicity, simp, }
end

lemma H_C_imp_A (e : evt)
: SPEC₂ v o sch ⋀ Wtn w ⋀ ◻(J ! ⦃o,w,v⦄) ⟹
  ◻(sch ≃ ↑e ⋀ ⟦ o,v | C e ⟧ ⟶ ⟦ o,w | A e ⟧) :=
begin [temporal]
  intro H',
  have H : temporal.one_to_one.SPEC₁ v o ⋀
           temporal.one_to_one.Wtn w ⋀
           ◻(J ! ⦃o,w,v⦄),
  { revert H',  persistent,
    intro, casesm* _ ⋀ _, split* ; try { assumption },
    apply temporal.one_to_one.SPEC₂_imp_SPEC₁ _ Γ _,
    auto, casesm* _ ⋀ _, auto, },
  clear Hpo,
  let J' := temporal.one_to_one.J',
  have SIM₀' := temporal.one_to_one.SIM₀', clear SIM₀,
  have SIM' := temporal.one_to_one.SIM',  clear SIM,
  have := C_imp_A_in_w p' _ (Next_a A) (Next_c C) J' SIM₀' SIM' v ⦃o,sch⦄ Γ _ w _,
  { persistent, henceforth at this ⊢,
    simp, intros h₀ h₁, clear_except this h₀ h₁,
    suffices : sch ≃ ↑e ⋀ ⟦ o,w | A e ⟧, apply this.right,
    rw abstract_sch, split, assumption,
    apply this _,
    simp [Next_c],
    suffices : ⟦ ⦃o,sch⦄,v | λ (σ σ' : (γ × evt) × β), (σ.fst).snd = e ∧ (C e on map_left fst) σ σ' ⟧,
    { revert this, action { simp, intro, subst e, simp, },  },
    rw [← action_and_action,← init_eq_action,action_on'], split,
    explicit
    { simp at ⊢ h₀, assumption },
    simp [h₁], },
  clear_except H',
  simp [simulation.SPEC₁,SPEC₂,temporal.one_to_one.SPEC₂] at H' ⊢,
  cases_matching* _ ⋀ _, split,
  { simp [q'], assumption, },
  { select H' : ◻(p_exists _), clear_except H',
    henceforth at H' ⊢, cases H' with i H',
    simp [Next_c],
    suffices : ⟦ ⦃o,sch⦄,v | λ (σ σ' : (γ × evt) × β), (σ.fst).snd = i ∧ (C i on map_left fst) σ σ' ⟧,
    { revert this, action { simp, intro, subst i, simp } },
    rw [← action_and_action], },
  { cases_matching* _ ⋀ _, assumption, },
end

lemma Hpo' (e : evt)
: one_to_one_po (SPEC₂ v o sch ⋀ Wtn w ⋀ ◻(J ! ⦃o,w,v⦄))
/- -/ (cs₁ e ! ⦃o,v⦄)
      (fs₁ e ! ⦃o,v⦄)
      (sch ≃ ↑e ⋀ ⟦ o,v | C e ⟧)
/- -/ (cs₀ e ! ⦃o,w⦄)
      (fs₀ e ! ⦃o,w⦄)
      ⟦ o,w | A e ⟧ :=
begin
  have
  : temporal.one_to_one.SPEC₂ v o sch ⋀ temporal.one_to_one.Wtn w ⋀ ◻(J ! ⦃o,w,v⦄) ⟹
    temporal.one_to_one.SPEC₁ v o ⋀ temporal.one_to_one.SPEC₀.saf w o ⋀ ◻(J ! ⦃o,w,v⦄),
  begin [temporal]
    simp, intros h₀ h₁ h₂,
    split*,
    { apply temporal.one_to_one.SPEC₂_imp_SPEC₁ Hpo _ h₀, },
    { apply temporal.one_to_one.witness_imp_SPEC₀_saf ; auto, },
    { auto }
  end,
  constructor ;
  try { cases (Hpo w e)
        ; transitivity
        ; [ apply this
          , assumption ] },
  apply temporal.one_to_one.H_C_imp_A Hpo,
end

end Simulation_POs

include H SIM₀ SIM Hpo

lemma sched_ref (i : evt) (w : tvar α)
 (Hw : Γ ⊢ Wtn w)
 (h : Γ ⊢ sched (cs₁ i ! ⦃o,v⦄) (fs₁ i ! ⦃o,v⦄) (sch ≃ ↑i ⋀ ⟦ o,v | C i ⟧))
: Γ ⊢ sched (cs₀ i ! ⦃o,w⦄) (fs₀ i ! ⦃o,w⦄) ⟦ o,w | A i ⟧ :=
begin [temporal]
  have H' := one_to_one.H' C v o sch _ H,
  have hJ : ◻(J' J ! ⦃⦃o,sch⦄,w,v⦄),
  { replace SIM₀ := SIM₀' _ SIM₀,
    replace SIM := SIM' A C J SIM,
    apply simulation.J_inv_in_w p' q' (Next_a A) _ (J' J) SIM₀ SIM _ ⦃o,sch⦄ _ H' w Hw },
  simp [J'] at hJ,
  have Hpo' := temporal.one_to_one.Hpo' Hpo w i,
  apply replacement Hpo' Γ _,
  tauto, auto,
end

lemma one_to_one
: Γ ⊢ ∃∃ w, SPEC₀ w o :=
begin [temporal]
  select_witness w : temporal.one_to_one.Wtn w with Hw,
  have this := H, revert this,
  dsimp [SPEC₀,SPEC₁],
  have H' := temporal.one_to_one.H' , -- o sch,
  apply ctx_p_and_p_imp_p_and' _ _,
  apply ctx_p_and_p_imp_p_and' _ _,
  { clear_except SIM₀ Hw H,
    replace SIM₀ := SIM₀' _ SIM₀,
    have := init_in_w p' q' (Next_a A) (J' J) SIM₀ v ⦃o,sch⦄ Γ,
    intro Hq,
    replace this := this _ Hw _, simp [p'] at this,
    apply this,
    simp [q',proj_assoc], apply Hq, },
  { clear_except SIM SIM₀ Hw H,
    have H' := H' C v o sch _ H,
    replace SIM₀ := SIM₀' _ SIM₀,
    replace SIM := SIM' A C J SIM,
    have := temporal.simulation.C_imp_A_in_w p' q'
      (Next_a A) (Next_c C) (J' J) SIM₀ SIM v ⦃o,sch⦄ _ H' w Hw,
    { monotonicity only,
      simp [exists_action],
      intros e h₀ h₁, replace this := this _,
      { revert this,
        explicit { simp [Next_a,on_fun], intros h, exact ⟨_,h⟩ }, },
      simp [Next_c],
      suffices : ⟦ ⦃o,sch⦄,v | λ (σ σ' : (γ × evt) × β), ((λ s s', s = e) on (prod.snd ∘ prod.fst)) σ σ' ∧ (C e on map_left prod.fst) σ σ' ⟧,
      revert this, action
      { simp [function.on_fun],
        intros, subst e, assumption, },
      rw ← action_and_action, simp,
      rw [action_on,action_on,coe_over_comp,proj_assoc,← init_eq_action,coe_eq],
      simp, split ; assumption } },
  { intros h i,
    replace h := h i,
    apply temporal.one_to_one.sched_ref ; auto },
end
end SPEC₂

section refinement_SPEC₂
include Hpo SIM₀ SIM
parameters cs₁ fs₁ cs₀ fs₀

lemma refinement_SPEC₂
: Γ ⊢ (∃∃ sch, SPEC₂ v o sch) ⟶ (∃∃ a, SPEC₀ a o) :=
begin [temporal]
  simp, intros sch Hc,
  apply one_to_one A C J SIM₀ SIM _ _ _ _ _  Hc
  ; assumption,
end
end refinement_SPEC₂

lemma refinement_SPEC₁
: SPEC₁ v o ⟹ (∃∃ sch, SPEC₂ v o sch) :=
sorry

include SIM₀ SIM
lemma refinement
  (h : ∀ c a e, one_to_one_po' (SPEC₁ c o ⋀ SPEC₀.saf a o ⋀ ◻(J ! ⦃o,a,c⦄))
         ⟨cs₁ e,fs₁ e,C e⟩
         ⟨cs₀ e,fs₀ e,A e⟩ ⦃o,c⦄ ⦃o,a⦄)
: (∃∃ c, SPEC₁ c o) ⟹ (∃∃ a, SPEC₀ a o) :=
begin [temporal]
  transitivity (∃∃ c sch, SPEC₂ q C cs₁ fs₁ c o sch),
  { apply p_exists_p_imp_p_exists ,
    intro v,
    apply refinement_SPEC₁, },
  { simp, intros c sch Hspec,
    specialize h c, simp [one_to_one_po'] at h,
    apply refinement_SPEC₂ A C cs₀ fs₀ cs₁ fs₁ J SIM₀ SIM c o _ _ _,
    exact h,
    existsi sch, assumption },
end

end
end one_to_one

end temporal