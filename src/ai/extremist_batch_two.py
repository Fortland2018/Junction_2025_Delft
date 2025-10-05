from openai import OpenAI, AsyncOpenAI
import json
import sys
import re
import asyncio
import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Get the API key from environment variables
api_key = os.getenv('API_KEY')


class HierarchicalExtremismDetector:
    def __init__(self):
        self.client = OpenAI(api_key=api_key)
        self.async_client = AsyncOpenAI(api_key=api_key)
        self._verbose = True  # Control printing

    def _call_llm(self, prompt):
        """Helper to call LLM (synchronous)"""
        try:
            # Add explicit JSON instruction
            json_prompt = prompt + "\n\nIMPORTANT: Return ONLY valid JSON. Do not include markdown code blocks, explanations, or any text outside the JSON object."
            
            response = self.client.chat.completions.create(
                model="gpt-4.1-nano",
                max_completion_tokens=4000,
                temperature=0,
                response_format={"type": "json_object"},
                messages=[{"role": "user", "content": json_prompt}]
            )
            content = response.choices[0].message.content
            if not content:
                raise ValueError("LLM returned empty response")
            if self._verbose:
                print(f"LLM Response: {content[:200]}...")
            return content
        except Exception as e:
            if self._verbose:
                print(f"Error calling LLM: {e}")
            raise
    
    async def _call_llm_async(self, prompt):
        """Helper to call LLM (asynchronous)"""
        try:
            # Add explicit JSON instruction
            json_prompt = prompt + "\n\nIMPORTANT: Return ONLY valid JSON. Do not include markdown code blocks, explanations, or any text outside the JSON object."
            
            response = await self.async_client.chat.completions.create(
                model="gpt-4.1-mini",
                max_completion_tokens=4000,
                temperature=0,
                response_format={"type": "json_object"},
                messages=[{"role": "user", "content": json_prompt}]
            )
            content = response.choices[0].message.content
            if not content:
                raise ValueError("LLM returned empty response")
            if self._verbose:
                print(f"LLM Response: {content[:200]}...")
            return content
        except Exception as e:
            if self._verbose:
                print(f"Error calling LLM: {e}")
            raise
    
    def _parse_json_response(self, response):
        """Parse JSON from LLM response, handling markdown code blocks"""
        original_response = response
        
        # First, try to extract from markdown code blocks
        if "```json" in response:
            json_start = response.find("```json") + 7
            json_end = response.find("```", json_start)
            if json_end != -1:
                response = response[json_start:json_end].strip()
            else:
                response = response[json_start:].strip()
        elif "```" in response:
            json_start = response.find("```") + 3
            json_end = response.find("```", json_start)
            if json_end != -1:
                response = response[json_start:json_end].strip()
            else:
                response = response[json_start:].strip()
        
        # Clean up common JSON issues
        response = re.sub(r',(\s*[}\]])', r'\1', response)
        
        # Try to parse
        try:
            return json.loads(response)
        except json.JSONDecodeError as e:
            print("\n" + "="*80, flush=True)
            print(f"JSON Decode Error: {e}", flush=True)
            print(f"Error at character {e.pos}", flush=True)
            print(f"Full response length: {len(original_response)} characters", flush=True)
            print("\n--- Full Response ---", flush=True)
            print(original_response, flush=True)
            print("\n--- Extracted JSON (if different) ---", flush=True)
            if response != original_response:
                print(response, flush=True)
            print("\n--- Context around error ---", flush=True)
            start = max(0, e.pos - 100)
            end = min(len(response), e.pos + 100)
            print(f"...{response[start:end]}...", flush=True)
            print("="*80 + "\n", flush=True)
            
            # Try multiple repair strategies
            repair_strategies = [
                # Strategy 1: Normalize whitespace
                lambda r: ' '.join(r.split()),
                # Strategy 2: Fix common quote issues
                lambda r: r.replace("'", '"'),
                # Strategy 3: Remove trailing commas more aggressively
                lambda r: re.sub(r',(\s*[}\]])', r'\1', r),
                # Strategy 4: Fix missing quotes around keys
                lambda r: re.sub(r'(\w+):', r'"\1":', r),
                # Strategy 5: Try to extract just the JSON object
                lambda r: re.search(r'\{.*\}', r, re.DOTALL).group(0) if re.search(r'\{.*\}', r, re.DOTALL) else r,
            ]
            
            for i, strategy in enumerate(repair_strategies, 1):
                try:
                    cleaned = strategy(response)
                    print(f"Attempting repair strategy {i}...", flush=True)
                    result = json.loads(cleaned)
                    print(f"Success with repair strategy {i}!", flush=True)
                    return result
                except (json.JSONDecodeError, AttributeError, TypeError) as e_repair:
                    print(f"Strategy {i} failed: {e_repair}", flush=True)
                    continue
            
            # If all strategies fail, return a default empty structure
            print("All repair strategies failed. Returning default structure.", flush=True)
            return {}
    
    # STAGE 1: PREPROCESSING
    def extract_linguistic_elements(self, text):
        """Extract basic linguistic components"""
        
        prompt = f"""Extract linguistic elements from this text.

Text: "{text}"

Extract and return as JSON:
1. All pronouns with their type (first-person-singular: I, me; first-person-plural: we, us, our; third-person-singular: he, she, they; third-person-plural: they, them, their)
2. All verbs with their form (base, past, present, imperative)
3. All adjectives
4. All adverbs
5. All modal verbs (must, will, should, can, etc.)
6. All named entities (people, organizations, locations, groups)
7. All noun phrases referring to groups of people

Return JSON:
{{
  "pronouns": [{{"word": "we", "type": "first-person-plural", "position": 0}}],
  "verbs": [{{"word": "destroy", "form": "base", "position": 5}}],
  "adjectives": ["dangerous", "evil"],
  "adverbs": ["completely", "always"],
  "modals": [{{"word": "must", "strength": "strong"}}],
  "entities": [{{"text": "Muslims", "type": "NORP"}}],
  "group_references": ["those people", "them"]
}}"""

        return self._parse_json_response(self._call_llm(prompt))
    
    # NEW: GROUP ANONYMIZATION
    def anonymize_groups(self, text, linguistic_elements):
        """Replace group names with anonymized placeholders
        
        Returns:
            tuple: (anonymized_text, group_mapping)
                anonymized_text: Text with groups replaced by [GROUP_A], [GROUP_B], etc.
                group_mapping: Dict mapping placeholder to original group name
        """
        if self._verbose:
            print("Anonymizing groups for unbiased scoring...")
        
        # Collect all group mentions from entities and group_references
        groups_to_anonymize = []
        
        # From entities (NORP = nationalities/religious/political groups)
        entities = linguistic_elements.get('entities', [])
        for entity in entities:
            if entity.get('type') in ['NORP', 'ORG', 'GPE']:
                group_text = entity.get('text', '')
                if group_text and group_text not in groups_to_anonymize:
                    groups_to_anonymize.append(group_text)
        
        # From group_references
        group_refs = linguistic_elements.get('group_references', [])
        for ref in group_refs:
            if ref and ref not in groups_to_anonymize:
                groups_to_anonymize.append(ref)
        
        if not groups_to_anonymize:
            if self._verbose:
                print("No groups identified for anonymization.")
            return text, {}
        
        # Create mapping and anonymize
        group_mapping = {}
        anonymized_text = text
        
        # Sort by length (descending) to avoid partial replacements
        groups_to_anonymize.sort(key=len, reverse=True)
        
        for idx, group in enumerate(groups_to_anonymize):
            placeholder = f"[GROUP_{chr(65 + idx)}]"  # GROUP_A, GROUP_B, etc.
            group_mapping[placeholder] = group
            
            # Case-insensitive replacement
            anonymized_text = re.sub(
                re.escape(group), 
                placeholder, 
                anonymized_text, 
                flags=re.IGNORECASE
            )
        
        if self._verbose:
            print(f"Anonymized {len(group_mapping)} group(s): {list(group_mapping.values())}")
            print(f"Anonymized text: {anonymized_text}")
        
        return anonymized_text, group_mapping
    
    # STAGE 2: PSYCHOLINGUISTIC FEATURES
    def extract_psycholinguistic_features(self, text, linguistic_elements):
        """Extract psycholinguistic patterns"""
        
        prompt = f"""Analyze psycholinguistic patterns in this text.

Text: "{text}"

Linguistic elements already extracted: {json.dumps(linguistic_elements)}

Calculate and return as JSON:

1. **Pronoun polarization**: Ratio of first-person-plural (we/us) to third-person-plural (they/them). High ratio suggests us-vs-them thinking.

2. **Modal certainty**: Count strong modals (must, will, shall, cannot) vs weak modals (might, could, may). High strong/weak ratio = high certainty.

3. **Imperative commands**: Count imperative verb forms. High count = direct calls to action.

4. **Absolutist language**: Count absolute terms (all, every, always, never, none, nothing, everything, completely, totally, utterly).

5. **Action orientation**: Ratio of verbs to adjectives. High ratio = action-focused.

6. **Hedge ratio**: Count qualifiers/hedges (some, many, certain, few, several, I think, possibly, maybe, arguably, perhaps) divided by total words. High ratio = speaker is hedging/qualifying.

7. **Negation density**: Count negation markers (not, isn't, aren't, wasn't, weren't, don't, doesn't, didn't, never, no, nor). Indicates disagreement or denial.

8. **Epistemic certainty**: Ratio of certainty markers (definitely, certainly, clearly, obviously, undoubtedly) to uncertainty markers (maybe, possibly, perhaps, might, could). Low ratio = low certainty.

9. **Attribution distance**: Is this reported speech where speaker distances themselves? Look for: "he said", "they claim", "according to", "someone told me", paired with disagreement like "but I disagree", "I don't agree", "I oppose". Return score 0-10 (0=direct assertion, 10=strongly distanced/disagreed).

Return JSON:
{{
  "us_them_ratio": float (0-10),
  "certainty_score": float (0-10),
  "imperative_count": int,
  "absolutist_terms": [{{"word": "always", "position": 3}}],
  "absolutist_score": float (0-10),
  "verb_adjective_ratio": float,
  "hedge_ratio": float (0-1),
  "negation_density": int,
  "epistemic_certainty": float (0-10),
  "attribution_distance": float (0-10)
}}"""

        return self._parse_json_response(self._call_llm(prompt))
    
    # STAGE 3A: DEHUMANIZATION DETECTION (ASYNC) - NOW USES ANONYMIZED TEXT
    async def detect_dehumanization_async(self, text):
        """Detect dehumanizing language (async version)"""
        
        prompt = f"""Identify dehumanizing language in this text.

Text: "{text}"

Look for metaphors that compare people to:
- Animals (vermin, rats, cockroaches, dogs, pigs, beasts, parasites)
- Disease (plague, virus, cancer, infection, contamination)
- Objects (trash, garbage, tools, machines)
- Subhuman terms (savages, barbarians, primitive)

For EACH instance found, extract:
- The dehumanizing term
- The type (animal/disease/object/subhuman)
- The surrounding context (5 words before and after)
- Which group it refers to (use the exact placeholder if present, e.g., [GROUP_A])

Return JSON:
{{
  "dehumanization_instances": [
    {{
      "term": "vermin",
      "type": "animal",
      "context": "treating [GROUP_A] like vermin that must",
      "target": "[GROUP_A]"
    }}
  ],
  "dehumanization_score": float (0-10, based on number and severity)
}}

If no dehumanization found, return empty array and score 0."""

        response = await self._call_llm_async(prompt)
        return self._parse_json_response(response)
    
    # STAGE 3B: VIOLENCE DETECTION (ASYNC) - NOW USES ANONYMIZED TEXT
    async def detect_violence_advocacy_async(self, text, linguistic_elements):
        """Detect calls for violence (async version)"""
        
        prompt = f"""Identify language advocating violence or harm.

Text: "{text}"

Look for verbs of violence in these categories:
- Kill/destroy: kill, murder, slaughter, massacre, execute, assassinate, destroy, annihilate, eliminate, eradicate, exterminate
- Harm: harm, hurt, attack, assault, beat, torture
- Remove: deport, expel, remove, cleanse, purge, "get rid of"

For EACH violent verb found, extract:
1. The verb
2. Who is doing the action (agent/subject)
3. Who receives the action (patient/object) - use exact placeholder if present
4. Is it imperative form? (command)
5. Does it have strong modal? (must/will)
6. Context (sentence it appears in)

Return JSON:
{{
  "violence_instances": [
    {{
      "verb": "eliminate",
      "agent": "we",
      "patient": "[GROUP_A]",
      "is_imperative": true,
      "has_modal": true,
      "modal": "must",
      "context": "we must eliminate all of [GROUP_A]"
    }}
  ],
  "violence_advocacy_score": float (0-10)
}}

Score based on:
- Presence of violence verbs (3 points)
- Imperative form (3 points)
- Strong modals (2 points)
- Multiple instances (2 points)"""

        response = await self._call_llm_async(prompt)
        return self._parse_json_response(response)
    
    # STAGE 3C: THREAT INFLATION (ASYNC) - NOW USES ANONYMIZED TEXT
    async def detect_threat_inflation_async(self, text):
        """Detect existential/apocalyptic framing (async version)"""
        
        prompt = f"""Identify threat inflation language.

Text: "{text}"

Look for:
1. **Existential threats**: words suggesting total destruction, end, extinction (destroy, end, extinction, annihilation, collapse, catastrophe, apocalypse, doom)

2. **Amplifiers**: words that intensify threats (totally, completely, utterly, absolutely, entirely)

3. **Scope expansion**: making specific issues seem universal ("destroying our country", "end of civilization", "threat to humanity")

Extract each instance and categorize.

Return JSON:
{{
  "existential_terms": [{{"word": "destroy", "context": "will destroy our nation"}}],
  "amplifiers": ["totally", "completely"],
  "scope_expansions": [{{"phrase": "threat to all of us", "scope": "universal"}}],
  "threat_score": float (0-10)
}}"""

        response = await self._call_llm_async(prompt)
        return self._parse_json_response(response)
    
    # STAGE 3D: OUTGROUP HOMOGENIZATION (ASYNC) - NOW USES ANONYMIZED TEXT
    async def detect_outgroup_homogenization_async(self, text):
        """Detect sweeping negative generalizations about groups (async version)"""
        
        prompt = f"""Identify NEGATIVE generalizations that treat an entire group as identical.

Text: "{text}"

Only flag hostile patterns, NOT positive/neutral statements (e.g., "X are great" should NOT be flagged).

Look for:
1. Universal quantifiers + negative attributes: "all X are dangerous", "every X wants to harm us"
2. Essentialist claims + negative valence: "X are criminals", "X want to destroy us"
3. No exceptions or nuance acknowledged (absence of "some", "many", "certain")

Return JSON:
{{
  "homogenization_patterns": [
    {{
      "pattern": "all_quantifier",
      "phrase": "all [GROUP_A] want to harm us",
      "group": "[GROUP_A]",
      "negative_attribute": "want to harm us"
    }}
  ],
  "homogenization_score": float (0-10)
}}

If no negative patterns found, return empty array and score 0."""

        response = await self._call_llm_async(prompt)
        return self._parse_json_response(response)
    
    # STAGE 4: MULTI-TASK CLASSIFICATION
    def classify_extremism_dimensions(self, all_features):
        """Synthesize all features into final scores using Stage 3 scores"""
        
        # Extract scores directly from Stage 3 results
        dehumanization_score = all_features.get("dehumanization", {}).get("dehumanization_score", 0.0)
        violence_score = all_features.get("violence", {}).get("violence_advocacy_score", 0.0)
        threat_score = all_features.get("threat", {}).get("threat_score", 0.0)
        homogenization_score = all_features.get("homogenization", {}).get("homogenization_score", 0.0)
        
        # Calculate absolutism score from psycholinguistic features
        psycho = all_features.get("psycholinguistic", {})
        absolutism_score = psycho.get("absolutist_score", 0.0)
        certainty_score = psycho.get("certainty_score", 0.0)
        # Combine absolutist terms and certainty for final absolutism score
        absolutism_final = (absolutism_score + certainty_score) / 2.0
        
        # Build final scores structure with evidence
        prompt = f"""Given these extracted features and scores, provide evidence and explanation for each dimension.

Extracted features:
{json.dumps(all_features, indent=2)}

The scores have already been calculated:
- Dehumanization: {dehumanization_score}
- Violence Advocacy: {violence_score}
- Absolutism: {absolutism_final}
- Threat Inflation: {threat_score}
- Outgroup Homogenization: {homogenization_score}

For each dimension, provide:
1. Key evidence (quote from features if available)
2. Brief explanation of why this score was given

Return ONLY valid JSON in this exact format:
{{
  "dehumanization": {{
    "score": {dehumanization_score},
    "evidence": "specific quote or description from features",
    "explanation": "brief reasoning"
  }},
  "violence_advocacy": {{
    "score": {violence_score},
    "evidence": "specific quote or description from features",
    "explanation": "brief reasoning"
  }},
  "absolutism": {{
    "score": {absolutism_final},
    "evidence": "specific quote or description from features",
    "explanation": "brief reasoning"
  }},
  "threat_inflation": {{
    "score": {threat_score},
    "evidence": "specific quote or description from features",
    "explanation": "brief reasoning"
  }},
  "outgroup_homogenization": {{
    "score": {homogenization_score},
    "evidence": "specific quote or description from features",
    "explanation": "brief reasoning"
  }}
}}

IMPORTANT: Use the EXACT scores provided above. Return ONLY the JSON object, no additional text or explanation."""

        return self._parse_json_response(self._call_llm(prompt))
    
    def calculate_overall_extremism(self, scores):
        """Calculate overall extremism score using max-score approach with contribution factor
        
        Formula:
        - max_score = max(scores)
        - mean_of_others = (sum(scores) - max_score) / (number_of_scores - 1)
        - final_score = min(10, max_score + (alpha * mean_of_others))
        
        Where alpha = 0.25 (contribution factor)
        
        This approach gives primary weight to the highest-scoring dimension while
        allowing other dimensions to contribute proportionally.
        """
        alpha = 0.25  # Contribution factor
        
        # Extract all dimension scores
        dimension_scores = []
        for dimension in ["violence_advocacy", "dehumanization", "outgroup_homogenization", 
                         "threat_inflation", "absolutism"]:
            if dimension in scores and "score" in scores[dimension]:
                dimension_scores.append(scores[dimension]["score"])
        
        # Handle edge cases
        if not dimension_scores:
            return 0.0
        if len(dimension_scores) == 1:
            return round(dimension_scores[0], 2)
        
        # Calculate using the new formula
        max_score = max(dimension_scores)
        mean_of_others = (sum(dimension_scores) - max_score) / (len(dimension_scores) - 1)
        final_score = min(10, max_score + (alpha * mean_of_others))
        
        return round(final_score, 2)
    
    # STAGE 5: TARGET EXTRACTION (USES ORIGINAL TEXT)
    def extract_targets(self, text, linguistic_elements):
        """Identify who is being targeted (uses original, non-anonymized text)"""
        
        prompt = f"""Identify the target group(s) in this text.

Text: "{text}"

Named entities found: {json.dumps(linguistic_elements.get('entities', []))}

Determine:
1. Which group(s) are described negatively or threatened
2. Category (ethnic, religious, political, national, ideological, criminal)
3. Specific phrases showing they are targeted

This is DESCRIPTIVE only - just identify the target, not whether it's justified.

Return JSON:
{{
  "targets": [
    {{
      "group": "specific group name",
      "category": "ethnic/religious/political/national/ideological/other",
      "evidence_phrases": ["phrase 1", "phrase 2"]
    }}
  ]
}}"""

        return self._parse_json_response(self._call_llm(prompt))
    
    # MAIN PIPELINE WITH PARALLELIZATION AND ANONYMIZATION
    def analyze(self, text):
        """Run full hierarchical pipeline with group anonymization for Stage 3"""
        
        if self._verbose:
            print("Stage 1: Extracting linguistic elements...")
        linguistic_elements = self.extract_linguistic_elements(text)
        
        if self._verbose:
            print("Stage 1b: Anonymizing groups...")
        anonymized_text, group_mapping = self.anonymize_groups(text, linguistic_elements)
        
        if self._verbose:
            print("Stage 2: Extracting psycholinguistic features...")
        psycho_features = self.extract_psycholinguistic_features(anonymized_text, linguistic_elements)
        
        if self._verbose:
            print("Stage 3: Detecting extremist patterns (PARALLEL, ANONYMIZED)...")
        # Run all 4 Stage 3 detections in parallel WITH ANONYMIZED TEXT
        dehumanization, violence, threat, homogenization = asyncio.run(
            self._run_stage3_parallel(anonymized_text, linguistic_elements)
        )
        
        # Combine all features
        all_features = {
            "linguistic_elements": linguistic_elements,
            "psycholinguistic": psycho_features,
            "dehumanization": dehumanization,
            "violence": violence,
            "threat": threat,
            "homogenization": homogenization
        }
        
        if self._verbose:
            print("Stage 4: Final classification...")
        final_scores = self.classify_extremism_dimensions(all_features)
        
        # Calculate overall extremism score
        overall_score = self.calculate_overall_extremism(final_scores)
        final_scores["overall_extremism"] = overall_score
        
        if self._verbose:
            print("Stage 5: Extracting targets (using original text)...")
        targets = self.extract_targets(text, linguistic_elements)  # Uses ORIGINAL text
        
        return {
            "scores": final_scores,
            "targets": targets,
            "raw_features": all_features,
            "group_mapping": group_mapping  # Include mapping for transparency
        }


    async def analyze_async(self, text: str):
            """Async entrypoint for ASGI servers (FastAPI)."""
            return await self._analyze_async(text)


    # OPTIMIZED ASYNC VERSION FOR BATCH PROCESSING
    async def _analyze_async(self, text, text_id=None):
        """Optimized async version with maximum parallelization"""
        
        # STAGE 1: Extract linguistic elements (required for everything)
        linguistic_elements_response = await self._call_llm_async(
            f"""Extract linguistic elements from this text.

Text: "{text}"

Extract and return as JSON:
1. All pronouns with their type (first-person-singular: I, me; first-person-plural: we, us, our; third-person-singular: he, she, they; third-person-plural: they, them, their)
2. All verbs with their form (base, past, present, imperative)
3. All adjectives
4. All adverbs
5. All modal verbs (must, will, should, can, etc.)
6. All named entities (people, organizations, locations, groups)
7. All noun phrases referring to groups of people

Return JSON:
{{
  "pronouns": [{{"word": "we", "type": "first-person-plural", "position": 0}}],
  "verbs": [{{"word": "destroy", "form": "base", "position": 5}}],
  "adjectives": ["dangerous", "evil"],
  "adverbs": ["completely", "always"],
  "modals": [{{"word": "must", "strength": "strong"}}],
  "entities": [{{"text": "Muslims", "type": "NORP"}}],
  "group_references": ["those people", "them"]
}}"""
        )
        linguistic_elements = self._parse_json_response(linguistic_elements_response)
        
        # STAGE 1b: Anonymize (quick, local operation)
        anonymized_text, group_mapping = self.anonymize_groups(text, linguistic_elements)
        
        # PARALLEL BATCH: Run Stage 2, Stage 3 (4 calls), and Stage 5 in parallel
        # Stage 2: Psycholinguistic
        psycho_task = self._call_llm_async(
            f"""Analyze psycholinguistic patterns in this text.

Text: "{anonymized_text}"

Linguistic elements already extracted: {json.dumps(linguistic_elements)}

Calculate and return as JSON:

1. **Pronoun polarization**: Ratio of first-person-plural (we/us) to third-person-plural (they/them). High ratio suggests us-vs-them thinking.

2. **Modal certainty**: Count strong modals (must, will, shall, cannot) vs weak modals (might, could, may). High strong/weak ratio = high certainty.

3. **Imperative commands**: Count imperative verb forms. High count = direct calls to action.

4. **Absolutist language**: Count absolute terms (all, every, always, never, none, nothing, everything, completely, totally, utterly).

5. **Action orientation**: Ratio of verbs to adjectives. High ratio = action-focused.

Return JSON:
{{
  "us_them_ratio": float (0-10),
  "certainty_score": float (0-10),
  "imperative_count": int,
  "absolutist_terms": [{{"word": "always", "position": 3}}],
  "absolutist_score": float (0-10),
  "verb_adjective_ratio": float
}}"""
        )
        
        # Stage 3: All 4 detections
        stage3_task = self._run_stage3_parallel(anonymized_text, linguistic_elements)
        
        # Stage 5: Target extraction (independent of Stages 2-4)
        targets_task = self._call_llm_async(
            f"""Identify the target group(s) in this text.

Text: "{text}"

Named entities found: {json.dumps(linguistic_elements.get('entities', []))}

Determine:
1. Which group(s) are described negatively or threatened
2. Category (ethnic, religious, political, national, ideological, criminal)
3. Specific phrases showing they are targeted

This is DESCRIPTIVE only - just identify the target, not whether it's justified.

Return JSON:
{{
  "targets": [
    {{
      "group": "specific group name",
      "category": "ethnic/religious/political/national/ideological/other",
      "evidence_phrases": ["phrase 1", "phrase 2"]
    }}
  ]
}}"""
        )
        
        # Wait for all parallel tasks
        psycho_response, (dehumanization, violence, threat, homogenization), targets_response = await asyncio.gather(
            psycho_task,
            stage3_task,
            targets_task
        )
        
        # Parse responses
        psycho_features = self._parse_json_response(psycho_response)
        targets = self._parse_json_response(targets_response)
        
        # Combine all features
        all_features = {
            "linguistic_elements": linguistic_elements,
            "psycholinguistic": psycho_features,
            "dehumanization": dehumanization,
            "violence": violence,
            "threat": threat,
            "homogenization": homogenization
        }
        
        # STAGE 4: Final classification (uses results from Stage 2 and 3)
        dehumanization_score = all_features.get("dehumanization", {}).get("dehumanization_score", 0.0)
        violence_score = all_features.get("violence", {}).get("violence_advocacy_score", 0.0)
        threat_score = all_features.get("threat", {}).get("threat_score", 0.0)
        homogenization_score = all_features.get("homogenization", {}).get("homogenization_score", 0.0)
        
        psycho = all_features.get("psycholinguistic", {})
        absolutism_score = psycho.get("absolutist_score", 0.0)
        certainty_score = psycho.get("certainty_score", 0.0)
        absolutism_final = (absolutism_score + certainty_score) / 2.0
        
        classification_response = await self._call_llm_async(
            f"""Given these extracted features and scores, provide evidence and explanation for each dimension.

Extracted features:
{json.dumps(all_features, indent=2)}

The scores have already been calculated:
- Dehumanization: {dehumanization_score}
- Violence Advocacy: {violence_score}
- Absolutism: {absolutism_final}
- Threat Inflation: {threat_score}
- Outgroup Homogenization: {homogenization_score}

For each dimension, provide:
1. Key evidence (quote from features if available)
2. Brief explanation of why this score was given

Return ONLY valid JSON in this exact format:
{{
  "dehumanization": {{
    "score": {dehumanization_score},
    "evidence": "specific quote or description from features",
    "explanation": "brief reasoning"
  }},
  "violence_advocacy": {{
    "score": {violence_score},
    "evidence": "specific quote or description from features",
    "explanation": "brief reasoning"
  }},
  "absolutism": {{
    "score": {absolutism_final},
    "evidence": "specific quote or description from features",
    "explanation": "brief reasoning"
  }},
  "threat_inflation": {{
    "score": {threat_score},
    "evidence": "specific quote or description from features",
    "explanation": "brief reasoning"
  }},
  "outgroup_homogenization": {{
    "score": {homogenization_score},
    "evidence": "specific quote or description from features",
    "explanation": "brief reasoning"
  }}
}}

IMPORTANT: Use the EXACT scores provided above. Return ONLY the JSON object, no additional text or explanation."""
        )
        final_scores = self._parse_json_response(classification_response)
        
        # Calculate overall extremism score
        overall_score = self.calculate_overall_extremism(final_scores)
        final_scores["overall_extremism"] = overall_score
        
        return {
            "scores": final_scores,
            "targets": targets,
            "raw_features": all_features,
            "group_mapping": group_mapping
        }
    
    # BATCH PROCESSING METHOD
    def batch_analyze(self, texts):
        """Analyze multiple texts in parallel
        
        Args:
            texts: List of strings or dict with 'id' and 'text' keys
                   e.g., ["text1", "text2"] or [{"id": "t1", "text": "..."}, ...]
        
        Returns:
            List of results in same order as input
        """
        # Disable verbose mode for batch processing
        original_verbose = self._verbose
        self._verbose = False
        
        print(f"Batch processing {len(texts)} texts...")
        
        # Normalize input format
        normalized_texts = []
        for i, item in enumerate(texts):
            if isinstance(item, dict):
                normalized_texts.append({
                    'id': item.get('id', i),
                    'text': item.get('text', '')
                })
            else:
                normalized_texts.append({
                    'id': i,
                    'text': item
                })
        
        # Run all analyses in parallel
        results = asyncio.run(self._batch_analyze_async(normalized_texts))
        
        # Restore verbose mode
        self._verbose = original_verbose
        
        return results
    
    async def _batch_analyze_async(self, normalized_texts):
        """Internal async method for batch processing"""
        # Create tasks for all texts
        tasks = [
            self._analyze_async(item['text'], text_id=item['id'])
            for item in normalized_texts
        ]
        
        # Run all tasks concurrently
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # Process results and handle exceptions
        processed_results = []
        for i, result in enumerate(results):
            if isinstance(result, Exception):
                print(f"Error processing text {normalized_texts[i]['id']}: {result}")
                processed_results.append({
                    "error": str(result),
                    "text_id": normalized_texts[i]['id']
                })
            else:
                result['text_id'] = normalized_texts[i]['id']
                processed_results.append(result)
        
        return processed_results
    
    async def _run_stage3_parallel(self, text, linguistic_elements):
        """Run Stage 3 detections in parallel (receives anonymized text)"""
        # Create all 4 tasks
        tasks = [
            self.detect_dehumanization_async(text),
            self.detect_violence_advocacy_async(text, linguistic_elements),
            self.detect_threat_inflation_async(text),
            self.detect_outgroup_homogenization_async(text)
        ]
        
        # Run all tasks concurrently
        results = await asyncio.gather(*tasks)
        
        # Return in order: dehumanization, violence, threat, homogenization
        return results[0], results[1], results[2], results[3]


# Usage example
if __name__ == "__main__":
    import time
    detector = HierarchicalExtremismDetector()
    
    # SINGLE TEXT ANALYSIS
    # print("\n" + "="*80)
    # print("SINGLE TEXT ANALYSIS")
    # print("="*80 + "\n")
    
    # test_text = "Muslims are trash."
    
    # start = time.time()
    # results = detector.analyze(test_text)
    # elapsed = time.time() - start
    
    # print(f"\n{'='*80}")
    # print(f"Single analysis completed in {elapsed:.2f} seconds")
    # print(f"{'='*80}\n")
    # print(json.dumps(results["scores"], indent=2))
    # print(f"\nGroup mapping: {results['group_mapping']}")
    
    # BATCH ANALYSIS
    print("\n\n" + "="*80)
    print("BATCH ANALYSIS DEMONSTRATION")
    print("="*80 + "\n")
    
    # Example with multiple texts
    test_texts = [
        "Hello  everyone,  this  video  is  only  allowed  to  be  used  as  test  data  for  the  Delft  Inclusive  Speech  Communication  Lab  Junction  X  Challenge.",
        "Muslims are trash.",

    ]
    
    start = time.time()
    batch_results = detector.batch_analyze(test_texts)
    elapsed = time.time() - start
    
    print(f"\n{'='*80}")
    print(f"Batch analysis of {len(test_texts)} texts completed in {elapsed:.2f} seconds")
    print(f"Average time per text: {elapsed/len(test_texts):.2f} seconds")
    print(f"Speedup vs sequential: {(7.0 * len(test_texts))/elapsed:.1f}x faster")
    print(f"{'='*80}\n")
    
    # Print summary of results
    print("BATCH RESULTS SUMMARY:")
    print("-" * 80)
    for i, result in enumerate(batch_results):
        if "error" in result:
            print(f"Text {i}: ERROR - {result['error']}")
        else:
            overall = result["scores"].get("overall_extremism", 0)
            targets = ", ".join([t["group"] for t in result["targets"].get("targets", [])])
            print(f"Text {i}: Overall Score = {overall:.1f}/10 | Targets = {targets or 'None'}")
    
    # Detailed results for first text
    print(f"\n{'='*80}")
    print("DETAILED SCORES FOR FIRST TEXT:")
    print(f"{'='*80}\n")
    if "error" not in batch_results[0]:
        for dimension, data in batch_results[0]["scores"].items():
            if dimension != "overall_extremism" and isinstance(data, dict):
                print(f"\n{dimension.upper().replace('_', ' ')}:")
                print(f"  Score: {data.get('score', 0):.1f}/10")
                print(f"  Evidence: {data.get('evidence', 'N/A')}")
        print(f"\n{'='*40}")
        print(f"OVERALL EXTREMISM: {batch_results[0]['scores'].get('overall_extremism', 0):.1f}/10")
        print(f"{'='*40}")