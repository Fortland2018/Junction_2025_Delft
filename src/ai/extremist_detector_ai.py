# from openai import OpenAI, AsyncOpenAI
# import json
# import sys
# import re
# import asyncio
# import os
# from dotenv import load_dotenv
#
# # Load environment variables from .env file
# load_dotenv()
#
# # Get the API key from environment variables
# api_key = os.getenv('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')
#
#
#
# class HierarchicalExtremismDetector:
#     def __init__(self):
#         self.client = OpenAI(api_key=api_key)
#         self.async_client = AsyncOpenAI(api_key=api_key)
#
#     def _call_llm(self, prompt):
#         """Helper to call LLM (synchronous)"""
#         try:
#             # Add explicit JSON instruction
#             json_prompt = prompt + "\n\nIMPORTANT: Return ONLY valid JSON. Do not include markdown code blocks, explanations, or any text outside the JSON object."
#
#             response = self.client.chat.completions.create(
#                 model="gpt-4.1-nano",
#                 max_completion_tokens=4000,
#                 temperature=0,
#                 response_format={"type": "json_object"},
#                 messages=[{"role": "user", "content": json_prompt}]
#             )
#             content = response.choices[0].message.content
#             if not content:
#                 raise ValueError("LLM returned empty response")
#             print(f"LLM Response: {content[:200]}...")
#             return content
#         except Exception as e:
#             print(f"Error calling LLM: {e}")
#             raise
#
#     async def _call_llm_async(self, prompt):
#         """Helper to call LLM (asynchronous)"""
#         try:
#             # Add explicit JSON instruction
#             json_prompt = prompt + "\n\nIMPORTANT: Return ONLY valid JSON. Do not include markdown code blocks, explanations, or any text outside the JSON object."
#
#             response = await self.async_client.chat.completions.create(
#                 model="gpt-4.1-mini",
#                 max_completion_tokens=4000,
#                 temperature=0,
#                 response_format={"type": "json_object"},
#                 messages=[{"role": "user", "content": json_prompt}]
#             )
#             content = response.choices[0].message.content
#             if not content:
#                 raise ValueError("LLM returned empty response")
#             print(f"LLM Response: {content[:200]}...")
#             return content
#         except Exception as e:
#             print(f"Error calling LLM: {e}")
#             raise
#
#     def _parse_json_response(self, response):
#         """Parse JSON from LLM response, handling markdown code blocks"""
#         original_response = response
#
#         # First, try to extract from markdown code blocks
#         if "```json" in response:
#             json_start = response.find("```json") + 7
#             json_end = response.find("```", json_start)
#             if json_end != -1:
#                 response = response[json_start:json_end].strip()
#             else:
#                 response = response[json_start:].strip()
#         elif "```" in response:
#             json_start = response.find("```") + 3
#             json_end = response.find("```", json_start)
#             if json_end != -1:
#                 response = response[json_start:json_end].strip()
#             else:
#                 response = response[json_start:].strip()
#
#         # Clean up common JSON issues
#         response = re.sub(r',(\s*[}\]])', r'\1', response)
#
#         # Try to parse
#         try:
#             return json.loads(response)
#         except json.JSONDecodeError as e:
#             print("\n" + "="*80, flush=True)
#             print(f"JSON Decode Error: {e}", flush=True)
#             print(f"Error at character {e.pos}", flush=True)
#             print(f"Full response length: {len(original_response)} characters", flush=True)
#             print("\n--- Full Response ---", flush=True)
#             print(original_response, flush=True)
#             print("\n--- Extracted JSON (if different) ---", flush=True)
#             if response != original_response:
#                 print(response, flush=True)
#             print("\n--- Context around error ---", flush=True)
#             start = max(0, e.pos - 100)
#             end = min(len(response), e.pos + 100)
#             print(f"...{response[start:end]}...", flush=True)
#             print("="*80 + "\n", flush=True)
#
#             # Try multiple repair strategies
#             repair_strategies = [
#                 # Strategy 1: Normalize whitespace
#                 lambda r: ' '.join(r.split()),
#                 # Strategy 2: Fix common quote issues
#                 lambda r: r.replace("'", '"'),
#                 # Strategy 3: Remove trailing commas more aggressively
#                 lambda r: re.sub(r',(\s*[}\]])', r'\1', r),
#                 # Strategy 4: Fix missing quotes around keys
#                 lambda r: re.sub(r'(\w+):', r'"\1":', r),
#                 # Strategy 5: Try to extract just the JSON object
#                 lambda r: re.search(r'\{.*\}', r, re.DOTALL).group(0) if re.search(r'\{.*\}', r, re.DOTALL) else r,
#             ]
#
#             for i, strategy in enumerate(repair_strategies, 1):
#                 try:
#                     cleaned = strategy(response)
#                     print(f"Attempting repair strategy {i}...", flush=True)
#                     result = json.loads(cleaned)
#                     print(f"Success with repair strategy {i}!", flush=True)
#                     return result
#                 except (json.JSONDecodeError, AttributeError, TypeError) as e_repair:
#                     print(f"Strategy {i} failed: {e_repair}", flush=True)
#                     continue
#
#             # If all strategies fail, return a default empty structure
#             print("All repair strategies failed. Returning default structure.", flush=True)
#             return {}
#
#     # STAGE 1: PREPROCESSING
#     def extract_linguistic_elements(self, text):
#         """Extract basic linguistic components"""
#
#         prompt = f"""Extract linguistic elements from this text.
#
# Text: "{text}"
#
# Extract and return as JSON:
# 1. All pronouns with their type (first-person-singular: I, me; first-person-plural: we, us, our; third-person-singular: he, she, they; third-person-plural: they, them, their)
# 2. All verbs with their form (base, past, present, imperative)
# 3. All adjectives
# 4. All adverbs
# 5. All modal verbs (must, will, should, can, etc.)
# 6. All named entities (people, organizations, locations, groups)
# 7. All noun phrases referring to groups of people
#
# Return JSON:
# {{
#   "pronouns": [{{"word": "we", "type": "first-person-plural", "position": 0}}],
#   "verbs": [{{"word": "destroy", "form": "base", "position": 5}}],
#   "adjectives": ["dangerous", "evil"],
#   "adverbs": ["completely", "always"],
#   "modals": [{{"word": "must", "strength": "strong"}}],
#   "entities": [{{"text": "Muslims", "type": "NORP"}}],
#   "group_references": ["those people", "them"]
# }}"""
#
#         return self._parse_json_response(self._call_llm(prompt))
#
#     # STAGE 2: PSYCHOLINGUISTIC FEATURES
#     def extract_psycholinguistic_features(self, text, linguistic_elements):
#         """Extract psycholinguistic patterns"""
#
#         prompt = f"""Analyze psycholinguistic patterns in this text.
#
# Text: "{text}"
#
# Linguistic elements already extracted: {json.dumps(linguistic_elements)}
#
# Calculate and return as JSON:
#
# 1. **Pronoun polarization**: Ratio of first-person-plural (we/us) to third-person-plural (they/them). High ratio suggests us-vs-them thinking.
#
# 2. **Modal certainty**: Count strong modals (must, will, shall, cannot) vs weak modals (might, could, may). High strong/weak ratio = high certainty.
#
# 3. **Imperative commands**: Count imperative verb forms. High count = direct calls to action.
#
# 4. **Absolutist language**: Count absolute terms (all, every, always, never, none, nothing, everything, completely, totally, utterly).
#
# 5. **Action orientation**: Ratio of verbs to adjectives. High ratio = action-focused.
#
# Return JSON:
# {{
#   "us_them_ratio": float (0-10),
#   "certainty_score": float (0-10),
#   "imperative_count": int,
#   "absolutist_terms": [{{"word": "always", "position": 3}}],
#   "absolutist_score": float (0-10),
#   "verb_adjective_ratio": float
# }}"""
#
#         return self._parse_json_response(self._call_llm(prompt))
#
#     # STAGE 3A: DEHUMANIZATION DETECTION (ASYNC)
#     async def detect_dehumanization_async(self, text):
#         """Detect dehumanizing language (async version)"""
#
#         prompt = f"""Identify dehumanizing language in this text.
#
# Text: "{text}"
#
# Look for metaphors that compare people to:
# - Animals (vermin, rats, cockroaches, dogs, pigs, beasts, parasites)
# - Disease (plague, virus, cancer, infection, contamination)
# - Objects (trash, garbage, tools, machines)
# - Subhuman terms (savages, barbarians, primitive)
#
# For EACH instance found, extract:
# - The dehumanizing term
# - The type (animal/disease/object/subhuman)
# - The surrounding context (5 words before and after)
# - Which group it refers to
#
# Return JSON:
# {{
#   "dehumanization_instances": [
#     {{
#       "term": "vermin",
#       "type": "animal",
#       "context": "treating immigrants like vermin that must",
#       "target": "immigrants"
#     }}
#   ],
#   "dehumanization_score": float (0-10, based on number and severity)
# }}
#
# If no dehumanization found, return empty array and score 0."""
#
#         response = await self._call_llm_async(prompt)
#         return self._parse_json_response(response)
#
#     # STAGE 3B: VIOLENCE DETECTION (ASYNC)
#     async def detect_violence_advocacy_async(self, text, linguistic_elements):
#         """Detect calls for violence (async version)"""
#
#         prompt = f"""Identify language advocating violence or harm.
#
# Text: "{text}"
#
# Look for verbs of violence in these categories:
# - Kill/destroy: kill, murder, slaughter, massacre, execute, assassinate, destroy, annihilate, eliminate, eradicate, exterminate
# - Harm: harm, hurt, attack, assault, beat, torture
# - Remove: deport, expel, remove, cleanse, purge, "get rid of"
#
# For EACH violent verb found, extract:
# 1. The verb
# 2. Who is doing the action (agent/subject)
# 3. Who receives the action (patient/object)
# 4. Is it imperative form? (command)
# 5. Does it have strong modal? (must/will)
# 6. Context (sentence it appears in)
#
# Return JSON:
# {{
#   "violence_instances": [
#     {{
#       "verb": "eliminate",
#       "agent": "we",
#       "patient": "them",
#       "is_imperative": true,
#       "has_modal": true,
#       "modal": "must",
#       "context": "we must eliminate all of them"
#     }}
#   ],
#   "violence_advocacy_score": float (0-10)
# }}
#
# Score based on:
# - Presence of violence verbs (3 points)
# - Imperative form (3 points)
# - Strong modals (2 points)
# - Multiple instances (2 points)"""
#
#         response = await self._call_llm_async(prompt)
#         return self._parse_json_response(response)
#
#     # STAGE 3C: THREAT INFLATION (ASYNC)
#     async def detect_threat_inflation_async(self, text):
#         """Detect existential/apocalyptic framing (async version)"""
#
#         prompt = f"""Identify threat inflation language.
#
# Text: "{text}"
#
# Look for:
# 1. **Existential threats**: words suggesting total destruction, end, extinction (destroy, end, extinction, annihilation, collapse, catastrophe, apocalypse, doom)
#
# 2. **Amplifiers**: words that intensify threats (totally, completely, utterly, absolutely, entirely)
#
# 3. **Scope expansion**: making specific issues seem universal ("destroying our country", "end of civilization", "threat to humanity")
#
# Extract each instance and categorize.
#
# Return JSON:
# {{
#   "existential_terms": [{{"word": "destroy", "context": "will destroy our nation"}}],
#   "amplifiers": ["totally", "completely"],
#   "scope_expansions": [{{"phrase": "threat to all of us", "scope": "universal"}}],
#   "threat_score": float (0-10)
# }}"""
#
#         response = await self._call_llm_async(prompt)
#         return self._parse_json_response(response)
#
#     # STAGE 3D: OUTGROUP HOMOGENIZATION (ASYNC)
#     async def detect_outgroup_homogenization_async(self, text):
#       """Detect sweeping negative generalizations about groups (async version)"""
#
#       prompt = f"""Identify NEGATIVE generalizations that treat an entire group as identical.
#
#   Text: "{text}"
#
#   Only flag hostile patterns, NOT positive/neutral statements (e.g., "X are great" should NOT be flagged).
#
#   Look for:
#   1. Universal quantifiers + negative attributes: "all X are dangerous", "every X wants to harm us"
#   2. Essentialist claims + negative valence: "X are criminals", "X want to destroy us"
#   3. No exceptions or nuance acknowledged (absence of "some", "many", "certain")
#
#   Return JSON:
#   {{
#     "homogenization_patterns": [
#       {{
#         "pattern": "all_quantifier",
#         "phrase": "all Muslims want to harm us",
#         "group": "Muslims",
#         "negative_attribute": "want to harm us"
#       }}
#     ],
#     "homogenization_score": float (0-10)
#   }}
#
#   If no negative patterns found, return empty array and score 0."""
#
#       response = await self._call_llm_async(prompt)
#       return self._parse_json_response(response)
#
#     # STAGE 4: MULTI-TASK CLASSIFICATION
#     def classify_extremism_dimensions(self, all_features):
#         """Synthesize all features into final scores using Stage 3 scores"""
#
#         # Extract scores directly from Stage 3 results
#         dehumanization_score = all_features.get("dehumanization", {}).get("dehumanization_score", 0.0)
#         violence_score = all_features.get("violence", {}).get("violence_advocacy_score", 0.0)
#         threat_score = all_features.get("threat", {}).get("threat_score", 0.0)
#         homogenization_score = all_features.get("homogenization", {}).get("homogenization_score", 0.0)
#
#         # Calculate absolutism score from psycholinguistic features
#         psycho = all_features.get("psycholinguistic", {})
#         absolutism_score = psycho.get("absolutist_score", 0.0)
#         certainty_score = psycho.get("certainty_score", 0.0)
#         # Combine absolutist terms and certainty for final absolutism score
#         absolutism_final = (absolutism_score + certainty_score) / 2.0
#
#         # Build final scores structure with evidence
#         prompt = f"""Given these extracted features and scores, provide evidence and explanation for each dimension.
#
# Extracted features:
# {json.dumps(all_features, indent=2)}
#
# The scores have already been calculated:
# - Dehumanization: {dehumanization_score}
# - Violence Advocacy: {violence_score}
# - Absolutism: {absolutism_final}
# - Threat Inflation: {threat_score}
# - Outgroup Homogenization: {homogenization_score}
#
# For each dimension, provide:
# 1. Key evidence (quote from original text if available)
# 2. Brief explanation of why this score was given
#
# Return ONLY valid JSON in this exact format:
# {{
#   "dehumanization": {{
#     "score": {dehumanization_score},
#     "evidence": "specific quote or description from features",
#     "explanation": "brief reasoning"
#   }},
#   "violence_advocacy": {{
#     "score": {violence_score},
#     "evidence": "specific quote or description from features",
#     "explanation": "brief reasoning"
#   }},
#   "absolutism": {{
#     "score": {absolutism_final},
#     "evidence": "specific quote or description from features",
#     "explanation": "brief reasoning"
#   }},
#   "threat_inflation": {{
#     "score": {threat_score},
#     "evidence": "specific quote or description from features",
#     "explanation": "brief reasoning"
#   }},
#   "outgroup_homogenization": {{
#     "score": {homogenization_score},
#     "evidence": "specific quote or description from features",
#     "explanation": "brief reasoning"
#   }}
# }}
#
# IMPORTANT: Use the EXACT scores provided above. Return ONLY the JSON object, no additional text or explanation."""
#
#         return self._parse_json_response(self._call_llm(prompt))
#
#     def calculate_overall_extremism(self, scores):
#         """Calculate overall extremism score using max-score approach with contribution factor
#
#         Formula:
#         - max_score = max(scores)
#         - mean_of_others = (sum(scores) - max_score) / (number_of_scores - 1)
#         - final_score = min(10, max_score + (alpha * mean_of_others))
#
#         Where alpha = 0.25 (contribution factor)
#
#         This approach gives primary weight to the highest-scoring dimension while
#         allowing other dimensions to contribute proportionally.
#         """
#         alpha = 0.25  # Contribution factor
#
#         # Extract all dimension scores
#         dimension_scores = []
#         for dimension in ["violence_advocacy", "dehumanization", "outgroup_homogenization",
#                          "threat_inflation", "absolutism"]:
#             if dimension in scores and "score" in scores[dimension]:
#                 dimension_scores.append(scores[dimension]["score"])
#
#         # Handle edge cases
#         if not dimension_scores:
#             return 0.0
#         if len(dimension_scores) == 1:
#             return round(dimension_scores[0], 2)
#
#         # Calculate using the new formula
#         max_score = max(dimension_scores)
#         mean_of_others = (sum(dimension_scores) - max_score) / (len(dimension_scores) - 1)
#         final_score = min(10, max_score + (alpha * mean_of_others))
#
#         return round(final_score, 2)
#
#     # STAGE 5: TARGET EXTRACTION
#     def extract_targets(self, text, linguistic_elements):
#         """Identify who is being targeted"""
#
#         prompt = f"""Identify the target group(s) in this text.
#
# Text: "{text}"
#
# Named entities found: {json.dumps(linguistic_elements.get('entities', []))}
#
# Determine:
# 1. Which group(s) are described negatively or threatened
# 2. Category (ethnic, religious, political, national, ideological, criminal)
# 3. Specific phrases showing they are targeted
#
# This is DESCRIPTIVE only - just identify the target, not whether it's justified.
#
# Return JSON:
# {{
#   "targets": [
#     {{
#       "group": "specific group name",
#       "category": "ethnic/religious/political/national/ideological/other",
#       "evidence_phrases": ["phrase 1", "phrase 2"]
#     }}
#   ]
# }}"""
#
#         return self._parse_json_response(self._call_llm(prompt))
#
#     # MAIN PIPELINE WITH PARALLELIZATION
#     def analyze(self, text):
#         """Run full hierarchical pipeline with Stage 3 parallelized"""
#
#         print("Stage 1: Extracting linguistic elements...")
#         linguistic_elements = self.extract_linguistic_elements(text)
#
#         print("Stage 2: Extracting psycholinguistic features...")
#         psycho_features = self.extract_psycholinguistic_features(text, linguistic_elements)
#
#         print("Stage 3: Detecting extremist patterns (PARALLEL)...")
#         # Run all 4 Stage 3 detections in parallel
#         dehumanization, violence, threat, homogenization = asyncio.run(
#             self._run_stage3_parallel(text, linguistic_elements)
#         )
#
#         # Combine all features
#         all_features = {
#             "linguistic_elements": linguistic_elements,
#             "psycholinguistic": psycho_features,
#             "dehumanization": dehumanization,
#             "violence": violence,
#             "threat": threat,
#             "homogenization": homogenization
#         }
#
#         print("Stage 4: Final classification...")
#         final_scores = self.classify_extremism_dimensions(all_features)
#
#         # Calculate overall extremism score
#         overall_score = self.calculate_overall_extremism(final_scores)
#         final_scores["overall_extremism"] = overall_score
#
#         print("Stage 5: Extracting targets...")
#         targets = self.extract_targets(text, linguistic_elements)
#
#         return {
#             "scores": final_scores,
#             "targets": targets,
#             "raw_features": all_features
#         }
#
#     async def _run_stage3_parallel(self, text, linguistic_elements):
#         """Run Stage 3 detections in parallel"""
#         # Create all 4 tasks
#         tasks = [
#             self.detect_dehumanization_async(text),
#             self.detect_violence_advocacy_async(text, linguistic_elements),
#             self.detect_threat_inflation_async(text),
#             self.detect_outgroup_homogenization_async(text)
#         ]
#
#         # Run all tasks concurrently
#         results = await asyncio.gather(*tasks)
#
#         # Return in order: dehumanization, violence, threat, homogenization
#         return results[0], results[1], results[2], results[3]
#
#
# # Usage example
# if __name__ == "__main__":
#     detector = HierarchicalExtremismDetector()
#
#     test_text = "They will never understand us, so we must protect ourselves."
#
#     import time
#     start = time.time()
#     results = detector.analyze(test_text)
#     elapsed = time.time() - start
#
#     print(f"\n{'='*80}")
#     print(f"Analysis completed in {elapsed:.2f} seconds")
#     print(f"{'='*80}\n")
#     print(json.dumps(results["scores"], indent=2))