# EPQ Functionality Plan for Audio Learning App

## Executive Summary
This document outlines the integration plan for adding Exam Practice Questions (EPQ) functionality to the existing Flutter audio learning application. The EPQ module will coexist with the audio learning features, allowing users to choose between audio content or practice questions for each course. The implementation leverages our existing technology stack (Flutter, Riverpod, Supabase) and download-first architecture while adding OpenRouter AI integration for interactive question assistance.

## Project Scope

### In Scope
- ✅ 6 question types (excluding drag & drop)
- ✅ Question versioning system
- ✅ Updateable questions with sync capability
- ✅ OpenRouter AI integration for explanations
- ✅ Offline-first with online sync
- ✅ Progress tracking and analytics
- ✅ Card flip animations for answers
- ✅ Integration with existing course structure

### Out of Scope
- ❌ Admin panel (questions managed externally)
- ❌ Drag & drop question type
- ❌ Question authoring within app
- ❌ Bulk import/export features

## Complexity Assessment

### Low Complexity (Leverage Existing)
- ✅ **Database**: Extend existing Supabase PostgreSQL
- ✅ **Authentication**: Current Cognito-Supabase bridge works perfectly
- ✅ **Download System**: Adapt existing pattern for questions
- ✅ **Progress Tracking**: Extend current progress service
- ✅ **State Management**: Apply existing Riverpod patterns

### Moderate Complexity (New Development)
- 🔄 **Question UI Components**: Build Flutter equivalents of React components
- 🔄 **Answer Validation**: Port TypeScript logic to Dart
- 🔄 **Version Management**: Implement question versioning with sync
- 🔄 **Update System**: Check for and download question updates

### Higher Complexity (Significant Effort)
- ⚠️ **OpenRouter Integration**: Implement streaming AI responses
- ⚠️ **Card Flip Animations**: Complex state management during animations
- ⚠️ **Sync Logic**: Handle offline/online state transitions

## Architecture Design

### 1. Database Schema with Versioning

```sql
-- Question Sets linked to courses
CREATE TABLE question_sets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id UUID REFERENCES courses(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  display_order INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Questions with version tracking
CREATE TABLE questions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  question_set_id UUID REFERENCES question_sets(id) ON DELETE CASCADE,
  question_type TEXT NOT NULL CHECK (question_type IN (
    'multiple_choice', 'numerical_entry', 'short_answer',
    'select_from_list', 'multiple_response', 'either_or'
  )),
  display_order INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Question versions (preserves history)
CREATE TABLE question_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  question_id UUID REFERENCES questions(id) ON DELETE CASCADE,
  version_number INTEGER NOT NULL,
  question_text TEXT NOT NULL,
  question_data JSONB NOT NULL, -- Contains options, correct answers, etc.
  explanation TEXT,
  is_current BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES users(id),
  UNIQUE(question_id, version_number)
);

-- User progress tracking
CREATE TABLE user_question_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  question_id UUID REFERENCES questions(id) ON DELETE CASCADE,
  question_version_id UUID REFERENCES question_versions(id),
  is_completed BOOLEAN DEFAULT false,
  is_correct BOOLEAN,
  user_answer JSONB,
  attempt_count INTEGER DEFAULT 0,
  time_spent_seconds INTEGER DEFAULT 0,
  last_attempted_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  UNIQUE(user_id, question_id)
);

-- AI conversation history
CREATE TABLE epq_ai_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  question_id UUID REFERENCES questions(id) ON DELETE CASCADE,
  question_version_id UUID REFERENCES question_versions(id),
  messages JSONB[] NOT NULL DEFAULT '{}',
  model_used TEXT,
  total_tokens INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Question update tracking
CREATE TABLE question_sync_status (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  question_set_id UUID REFERENCES question_sets(id) ON DELETE CASCADE,
  last_sync_at TIMESTAMPTZ,
  local_version INTEGER NOT NULL DEFAULT 0,
  server_version INTEGER NOT NULL DEFAULT 0,
  needs_update BOOLEAN DEFAULT false,
  UNIQUE(user_id, question_set_id)
);

-- Indexes for performance
CREATE INDEX idx_question_versions_current ON question_versions(question_id, is_current);
CREATE INDEX idx_user_progress_user ON user_question_progress(user_id);
CREATE INDEX idx_user_progress_completed ON user_question_progress(user_id, is_completed);
CREATE INDEX idx_ai_conversations_user_question ON epq_ai_conversations(user_id, question_id);
CREATE INDEX idx_sync_status_needs_update ON question_sync_status(user_id, needs_update);
```

### 2. Data Models

```dart
// lib/models/epq/question_set.dart
class QuestionSet {
  final String id;
  final String courseId;
  final String title;
  final String? description;
  final int displayOrder;
  final List<Question> questions;
  final int completedCount;
  final int totalCount;
  
  double get completionPercentage => 
    totalCount > 0 ? (completedCount / totalCount) * 100 : 0;
}

// lib/models/epq/question.dart
class Question {
  final String id;
  final String questionSetId;
  final QuestionType type;
  final int displayOrder;
  final QuestionVersion currentVersion;
  final bool isCompleted;
  final bool? isCorrect;
  final int attemptCount;
}

// lib/models/epq/question_version.dart
class QuestionVersion {
  final String id;
  final String questionId;
  final int versionNumber;
  final String questionText;
  final Map<String, dynamic> questionData;
  final String? explanation;
  final bool isCurrent;
  final DateTime createdAt;
}

// lib/models/epq/question_type.dart
enum QuestionType {
  multipleChoice,
  numericalEntry,
  shortAnswer,
  selectFromList,
  multipleResponse,
  eitherOr,
}

// lib/models/epq/answer_validation.dart
class AnswerValidation {
  final bool isCorrect;
  final String? feedback;
  final Map<String, dynamic>? metadata;
}
```

### 3. Service Architecture

```dart
// lib/services/epq/question_service.dart
class QuestionService {
  final SupabaseClient _supabase;
  final LocalStorageService _localStorage;
  
  // Fetch questions with version check
  Future<List<QuestionSet>> getQuestionSets(String courseId) async {
    // 1. Check local cache first
    // 2. Check for updates from server
    // 3. Download new versions if available
    // 4. Return merged data
  }
  
  // Download new question versions
  Future<void> syncQuestions(String courseId) async {
    // 1. Get server version numbers
    // 2. Compare with local versions
    // 3. Download updated questions
    // 4. Update local storage
    // 5. Mark sync status
  }
  
  // Get specific question with current version
  Future<Question> getQuestion(String questionId) async {
    // Returns question with current version
  }
}

// lib/services/epq/answer_validation_service.dart
class AnswerValidationService {
  bool validateAnswer(QuestionType type, dynamic userAnswer, 
                     Map<String, dynamic> correctAnswer) {
    switch (type) {
      case QuestionType.multipleChoice:
        return _validateMultipleChoice(userAnswer, correctAnswer);
      case QuestionType.numericalEntry:
        return _validateNumerical(userAnswer, correctAnswer);
      case QuestionType.shortAnswer:
        return _validateShortAnswer(userAnswer, correctAnswer);
      case QuestionType.selectFromList:
        return _validateSelectFromList(userAnswer, correctAnswer);
      case QuestionType.multipleResponse:
        return _validateMultipleResponse(userAnswer, correctAnswer);
      case QuestionType.eitherOr:
        return _validateEitherOr(userAnswer, correctAnswer);
    }
  }
  
  // Individual validation methods...
}

// lib/services/epq/openrouter_service.dart
class OpenRouterService {
  final String apiKey = EnvConfig.openRouterApiKey;
  final Dio _dio = DioProvider.instance;
  
  Stream<String> streamExplanation({
    required String question,
    required String userAnswer,
    required String correctAnswer,
    required String? explanation,
    required List<ChatMessage> history,
    String model = 'anthropic/claude-3-haiku',
  }) async* {
    // Implementation using Server-Sent Events
    final response = await _dio.post(
      'https://openrouter.ai/api/v1/chat/completions',
      options: Options(
        headers: {
          'Authorization': 'Bearer $apiKey',
          'HTTP-Referer': 'com.example.audiolearning',
          'X-Title': 'Audio Learning App EPQ',
        },
        responseType: ResponseType.stream,
      ),
      data: {
        'model': model,
        'messages': _buildMessages(question, userAnswer, correctAnswer, history),
        'stream': true,
      },
    );
    
    // Parse SSE stream and yield content
    await for (final chunk in response.data.stream) {
      // Parse and yield text chunks
    }
  }
}

// lib/services/epq/progress_tracking_service.dart
class EPQProgressService {
  Future<void> saveProgress({
    required String userId,
    required String questionId,
    required String versionId,
    required dynamic userAnswer,
    required bool isCorrect,
    required int timeSpent,
  }) async {
    // Save to local storage immediately
    // Queue for sync to Supabase
    // Handle offline scenarios
  }
  
  Future<Map<String, QuestionProgress>> getUserProgress(String userId) async {
    // Get progress for all questions
  }
}
```

### 4. UI Component Structure

```dart
// lib/screens/epq/course_tools_screen.dart
class CourseToolsScreen extends ConsumerWidget {
  final String courseId;
  final String courseTitle;
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(courseTitle)),
      body: Column(
        children: [
          ToolCard(
            icon: Icons.headphones,
            title: 'Audio Learning',
            subtitle: 'Listen to course content',
            onTap: () => Navigator.pushNamed(context, '/assignments'),
          ),
          ToolCard(
            icon: Icons.quiz,
            title: 'Practice Questions',
            subtitle: 'Test your knowledge',
            onTap: () => Navigator.pushNamed(context, '/epq/question-sets'),
          ),
        ],
      ),
    );
  }
}

// lib/screens/epq/question_sets_screen.dart
class QuestionSetsScreen extends ConsumerWidget {
  // List all question sets for the course
  // Show progress for each set
  // Handle sync/update checks
}

// lib/screens/epq/question_screen.dart
class QuestionScreen extends ConsumerStatefulWidget {
  // Display current question
  // Handle answer input based on type
  // Validate and show flip animation
}

// lib/widgets/epq/question_widgets.dart
abstract class QuestionWidget extends StatelessWidget {
  final QuestionVersion question;
  final Function(dynamic answer) onAnswerSubmit;
  
  Widget buildQuestionContent();
  Widget buildAnswerInput();
}

class MultipleChoiceWidget extends QuestionWidget { }
class NumericalEntryWidget extends QuestionWidget { }
class ShortAnswerWidget extends QuestionWidget { }
class SelectFromListWidget extends QuestionWidget { }
class MultipleResponseWidget extends QuestionWidget { }
class EitherOrWidget extends QuestionWidget { }

// lib/widgets/epq/answer_card.dart
class AnswerCard extends ConsumerWidget {
  final bool isCorrect;
  final String? explanation;
  final Question question;
  
  // Shows static explanation
  // Provides "Ask AI" button
  // Handles flip animation
}

// lib/widgets/epq/ai_assistant_dialog.dart
class AIAssistantDialog extends ConsumerStatefulWidget {
  // Chat interface with OpenRouter
  // Streaming responses
  // Conversation history
}
```

### 5. State Management

```dart
// lib/providers/epq/question_providers.dart

// Current question set being viewed
final currentQuestionSetProvider = StateProvider<QuestionSet?>((ref) => null);

// Questions for current set
final questionsProvider = FutureProvider.family<List<Question>, String>(
  (ref, questionSetId) async {
    final service = ref.watch(questionServiceProvider);
    return service.getQuestionsForSet(questionSetId);
  },
);

// Current question being answered
final currentQuestionProvider = StateNotifierProvider<CurrentQuestionNotifier, QuestionState>(
  (ref) => CurrentQuestionNotifier(),
);

// User's answer state
final userAnswerProvider = StateProvider<dynamic>((ref) => null);

// Answer validation result
final answerValidationProvider = Provider<AnswerValidation?>((ref) {
  final question = ref.watch(currentQuestionProvider);
  final userAnswer = ref.watch(userAnswerProvider);
  
  if (question == null || userAnswer == null) return null;
  
  final service = ref.watch(answerValidationServiceProvider);
  return service.validate(question, userAnswer);
});

// AI conversation state
final aiConversationProvider = StateNotifierProvider<AIConversationNotifier, List<ChatMessage>>(
  (ref) => AIConversationNotifier(ref),
);

// Question sync status
final questionSyncProvider = StreamProvider<SyncStatus>((ref) async* {
  // Monitor for question updates
  // Yield sync status changes
});

// Progress tracking
final epqProgressProvider = StateNotifierProvider<EPQProgressNotifier, Map<String, double>>(
  (ref) => EPQProgressNotifier(ref),
);
```

## Implementation Phases

### Phase 1: Foundation (Week 1-2)
**Goal**: Set up database, models, and basic navigation

1. **Database Setup**
   - Create all EPQ tables in Supabase
   - Set up RLS policies for user access
   - Create indexes for performance
   - Test migration scripts

2. **Data Models & Services**
   - Create all EPQ data models
   - Build QuestionService with basic CRUD
   - Implement local storage for questions
   - Set up version management system

3. **Navigation Structure**
   - Add Course Tools screen
   - Create EPQ navigation flow
   - Update home screen course cards
   - Add routing configuration

**Deliverables**:
- Working database schema
- Basic model classes
- Navigation to EPQ module

### Phase 2: Core Question System (Week 3-4)
**Goal**: Implement question display and basic answer validation

1. **Question Display Components**
   - Build question type widgets
   - Implement multiple choice first
   - Add numerical entry
   - Create short answer input

2. **Answer Validation**
   - Port validation logic from TypeScript
   - Handle answer submission flow
   - Show immediate feedback
   - Save progress locally

3. **Static Explanations**
   - Display explanation after answer
   - Implement basic card flip animation
   - Show correct/incorrect status
   - Add "next question" navigation

**Deliverables**:
- 3 working question types
- Answer validation system
- Basic progress tracking

### Phase 3: Advanced Question Types (Week 5)
**Goal**: Complete remaining question types

1. **Complex Question Types**
   - Implement select from list
   - Build multiple response
   - Create either/or questions
   - Add fill-in-the-blank support

2. **Enhanced Validation**
   - Handle complex answer formats
   - Support partial credit
   - Implement retry logic
   - Add hint system

**Deliverables**:
- All 6 question types working
- Complete validation system
- Retry and hint features

### Phase 4: Sync & Updates (Week 6-7)
**Goal**: Implement question versioning and sync

1. **Version Management**
   - Track question versions locally
   - Check for updates on app launch
   - Download new versions in background
   - Handle version conflicts

2. **Sync System**
   - Build offline queue for progress
   - Implement sync on connectivity
   - Handle conflict resolution
   - Add pull-to-refresh

3. **Progress Persistence**
   - Save all attempts locally
   - Sync to Supabase when online
   - Calculate statistics
   - Show progress indicators

**Deliverables**:
- Working sync system
- Question update capability
- Offline/online handling

### Phase 5: AI Integration (Week 8-9)
**Goal**: Add OpenRouter AI assistant

1. **OpenRouter Setup**
   - Configure API integration
   - Implement streaming responses
   - Handle rate limiting
   - Add error recovery

2. **Chat Interface**
   - Build chat UI component
   - Handle message display
   - Add typing indicators
   - Implement conversation history

3. **Context Management**
   - Pass question context to AI
   - Include user answer and correct answer
   - Maintain conversation state
   - Save conversations for continuity

**Deliverables**:
- Working AI assistant
- Streaming chat interface
- Conversation persistence

### Phase 6: Polish & Optimization (Week 10)
**Goal**: Refine UX and optimize performance

1. **UI Polish**
   - Refine animations
   - Add loading states
   - Improve error messages
   - Ensure consistent styling

2. **Performance Optimization**
   - Optimize database queries
   - Reduce memory usage
   - Cache frequently used data
   - Improve sync efficiency

3. **Testing & QA**
   - Unit test validation logic
   - Integration test sync system
   - UI testing for all question types
   - Performance profiling

**Deliverables**:
- Polished UI/UX
- Optimized performance
- Comprehensive test coverage

## Technical Implementation Details

### Package Dependencies

```yaml
dependencies:
  # Existing packages...
  
  # EPQ-specific packages
  flip_card: ^0.7.0                    # Card flip animations
  flutter_html: ^3.0.0-alpha.6         # Rich text in questions
  flutter_markdown: ^0.6.18            # Markdown rendering
  http: ^1.1.0                         # For SSE streaming
  event_source: ^0.2.0                 # SSE client
  flutter_math_fork: ^0.7.1           # Math equations
  collection: ^1.18.0                  # Advanced collections
```

### OpenRouter Configuration

```dart
class OpenRouterConfig {
  static const String baseUrl = 'https://openrouter.ai/api/v1';
  
  static const Map<String, String> models = {
    'fast': 'anthropic/claude-3-haiku',
    'balanced': 'anthropic/claude-3-sonnet',
    'powerful': 'openai/gpt-4-turbo',
  };
  
  static const Map<String, String> headers = {
    'HTTP-Referer': 'com.example.audiolearning',
    'X-Title': 'Audio Learning EPQ',
  };
}
```

### Local Storage Structure

```
/app_data/
├── epq/
│   ├── questions/
│   │   ├── {course_id}/
│   │   │   ├── sets.json           # Question set metadata
│   │   │   ├── questions.json      # All questions
│   │   │   └── versions.json       # Version tracking
│   ├── progress/
│   │   ├── attempts.json           # User attempts
│   │   ├── completed.json          # Completion status
│   │   └── sync_queue.json         # Pending syncs
│   └── conversations/
│       └── {question_id}.json      # AI conversation history
```

### Answer Validation Examples

```dart
// Multiple Choice Validation
bool _validateMultipleChoice(String userAnswer, Map<String, dynamic> correct) {
  return userAnswer == correct['answer'];
}

// Numerical Entry Validation (with tolerance)
bool _validateNumerical(String userAnswer, Map<String, dynamic> correct) {
  final userNum = double.tryParse(userAnswer);
  if (userNum == null) return false;
  
  final correctNum = correct['answer'] as double;
  final tolerance = correct['tolerance'] ?? 0.01;
  
  return (userNum - correctNum).abs() <= tolerance;
}

// Short Answer Validation (with normalization)
bool _validateShortAnswer(String userAnswer, Map<String, dynamic> correct) {
  final normalized = userAnswer.toLowerCase().trim();
  final acceptableAnswers = List<String>.from(correct['answers']);
  
  return acceptableAnswers.any((answer) => 
    answer.toLowerCase().trim() == normalized
  );
}
```

## Migration from React EPQ

### What We'll Reuse
- ✅ Database schema (with modifications)
- ✅ Question data structure
- ✅ Validation logic (ported to Dart)
- ✅ AI conversation prompts
- ✅ Progress tracking concepts

### What Needs Rewriting
- ⚠️ All UI components (React → Flutter)
- ⚠️ State management (React Query → Riverpod)
- ⚠️ API calls (Express → Supabase)
- ⚠️ Animations (CSS → Flutter)

### Key Differences
| Aspect | React EPQ | Flutter EPQ |
|--------|-----------|-------------|
| Backend | Node.js + Express | Supabase Edge Functions |
| State | React Query | Riverpod |
| Styling | Tailwind CSS | Flutter Widgets |
| AI | OpenRouter direct | OpenRouter via Dio |
| Storage | PostgreSQL only | PostgreSQL + Local |
| Auth | Passport.js | Existing Cognito bridge |

## Success Metrics

### Performance Targets
- Question load time: <500ms
- Answer validation: <100ms
- AI response start: <2 seconds
- Sync operation: <5 seconds
- Offline capability: 100%

### User Experience Goals
- Smooth animations at 60fps
- No data loss in offline mode
- Seamless sync when online
- Intuitive question navigation
- Helpful AI explanations

### Technical Goals
- 80% code coverage in tests
- Zero critical bugs
- <5% crash rate
- Successful offline/online transitions
- Accurate answer validation

## Risk Mitigation

### Technical Risks
1. **OpenRouter API Changes**
   - Mitigation: Abstract API calls, version lock
   
2. **Complex Validation Logic**
   - Mitigation: Extensive testing, port carefully

3. **Sync Conflicts**
   - Mitigation: Clear conflict resolution rules

4. **Performance Issues**
   - Mitigation: Profile early, optimize queries

### Project Risks
1. **Scope Creep**
   - Mitigation: Stick to 6 question types only

2. **Integration Complexity**
   - Mitigation: Modular architecture, clear boundaries

3. **Testing Coverage**
   - Mitigation: Test each question type thoroughly

## Next Steps

1. **Immediate Actions**
   - Set up EPQ database tables
   - Create data models
   - Build navigation structure

2. **Week 1 Goals**
   - Complete Phase 1 foundation
   - Have basic question display working
   - Test with multiple choice questions

3. **First Milestone**
   - 3 question types working
   - Basic validation complete
   - Progress tracking functional

## Conclusion

The EPQ integration is a substantial but manageable addition to the audio learning app. By leveraging the existing architecture and following a phased approach, we can deliver a robust question practice system that complements the audio learning features. The modular design ensures that each component can be developed and tested independently, reducing risk and allowing for incremental delivery.

The estimated 10-week timeline provides buffer for unexpected challenges while maintaining steady progress toward feature parity with the React EPQ application. The focus on offline-first design with sync capabilities ensures users can practice questions anywhere, maintaining consistency with the app's core value proposition of learning on-the-go.