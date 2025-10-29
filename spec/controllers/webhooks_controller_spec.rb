require 'rails_helper'

RSpec.describe WebhooksController, type: :request do
  describe 'POST /webhooks/cursor/:task_id' do
    let(:task) { create(:task, :running) }
    
    context 'when status is FINISHED' do
      let(:pr_url) { 'https://github.com/user/repo/pull/123' }
      let(:payload) do
        {
          status: 'FINISHED',
          target: {
            prUrl: pr_url
          }
        }
      end

      it 'transitions task to pr_open status' do
        post "/webhooks/cursor/#{task.id}", params: payload, as: :json
        
        expect(response).to have_http_status(:ok)
        expect(task.reload.status).to eq('pr_open')
      end

      it 'saves the PR URL' do
        post "/webhooks/cursor/#{task.id}", params: payload, as: :json
        
        expect(task.reload.pr_url).to eq(pr_url)
      end

      it 'appends log message to debug_log' do
        post "/webhooks/cursor/#{task.id}", params: payload, as: :json
        
        task.reload
        expect(task.debug_log).to include('Cursor agent finished')
        expect(task.debug_log).to include(pr_url)
      end

      it 'returns success response' do
        post "/webhooks/cursor/#{task.id}", params: payload, as: :json
        
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['task_id']).to eq(task.id)
        expect(json_response['status']).to eq('FINISHED')
      end

      context 'with alternate PR URL format (pr_url)' do
        let(:payload) do
          {
            status: 'FINISHED',
            target: {
              pr_url: pr_url
            }
          }
        end

        it 'still saves the PR URL' do
          post "/webhooks/cursor/#{task.id}", params: payload, as: :json
          
          expect(task.reload.pr_url).to eq(pr_url)
        end
      end

      context 'with direct PR URL parameter' do
        let(:payload) do
          {
            status: 'FINISHED',
            pr_url: pr_url
          }
        end

        it 'saves the PR URL from direct parameter' do
          post "/webhooks/cursor/#{task.id}", params: payload, as: :json
          
          expect(task.reload.pr_url).to eq(pr_url)
        end
      end

      context 'without PR URL in payload' do
        let(:payload) do
          {
            status: 'FINISHED'
          }
        end

        it 'still transitions to pr_open' do
          post "/webhooks/cursor/#{task.id}", params: payload, as: :json
          
          expect(task.reload.status).to eq('pr_open')
        end

        it 'does not set pr_url' do
          post "/webhooks/cursor/#{task.id}", params: payload, as: :json
          
          expect(task.reload.pr_url).to be_nil
        end

        it 'includes warning in log' do
          post "/webhooks/cursor/#{task.id}", params: payload, as: :json
          
          expect(task.reload.debug_log).to include('URL not provided')
        end
      end
    end

    context 'when status is RUNNING' do
      let(:pending_task) { create(:task, status: :pending) }
      let(:payload) { { status: 'RUNNING' } }

      it 'transitions pending task to running status' do
        post "/webhooks/cursor/#{pending_task.id}", params: payload, as: :json
        
        expect(response).to have_http_status(:ok)
        expect(pending_task.reload.status).to eq('running')
      end

      it 'appends log message' do
        post "/webhooks/cursor/#{pending_task.id}", params: payload, as: :json
        
        expect(pending_task.reload.debug_log).to include('Cursor agent is now running')
      end

      it 'does not update task that is already past running' do
        pr_open_task = create(:task, :pr_open)
        original_status = pr_open_task.status
        
        post "/webhooks/cursor/#{pr_open_task.id}", params: payload, as: :json
        
        expect(pr_open_task.reload.status).to eq(original_status)
      end

      it 'returns success response' do
        post "/webhooks/cursor/#{pending_task.id}", params: payload, as: :json
        
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
      end
    end

    context 'when status is ERROR' do
      let(:payload) do
        {
          status: 'ERROR',
          error_message: 'Something went wrong'
        }
      end

      it 'transitions task to failed status' do
        post "/webhooks/cursor/#{task.id}", params: payload, as: :json
        
        expect(response).to have_http_status(:ok)
        expect(task.reload.status).to eq('failed')
      end

      it 'includes error message in log' do
        post "/webhooks/cursor/#{task.id}", params: payload, as: :json
        
        task.reload
        expect(task.debug_log).to include('Cursor agent failed')
        expect(task.debug_log).to include('Something went wrong')
      end

      context 'with different error field names' do
        let(:payload) do
          {
            status: 'ERROR',
            error: 'Different error format'
          }
        end

        it 'extracts error message from error field' do
          post "/webhooks/cursor/#{task.id}", params: payload, as: :json
          
          expect(task.reload.debug_log).to include('Different error format')
        end
      end

      context 'without error message' do
        let(:payload) { { status: 'ERROR' } }

        it 'uses default error message' do
          post "/webhooks/cursor/#{task.id}", params: payload, as: :json
          
          expect(task.reload.debug_log).to include('Unknown error')
        end
      end
    end

    context 'when task is not found' do
      it 'returns 404 error' do
        post '/webhooks/cursor/999999', params: { status: 'FINISHED' }, as: :json
        
        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Task not found')
      end
    end

    context 'when payload is invalid (missing status)' do
      it 'returns 400 error' do
        post "/webhooks/cursor/#{task.id}", params: {}, as: :json
        
        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Invalid payload')
      end
    end

    context 'when status is unknown' do
      let(:payload) { { status: 'UNKNOWN_STATUS' } }

      it 'still returns success' do
        post "/webhooks/cursor/#{task.id}", params: payload, as: :json
        
        expect(response).to have_http_status(:ok)
      end

      it 'does not change task status' do
        original_status = task.status
        post "/webhooks/cursor/#{task.id}", params: payload, as: :json
        
        expect(task.reload.status).to eq(original_status)
      end
    end

    context 'with nested data structure' do
      let(:payload) do
        {
          event: 'FINISHED',
          data: {
            pr_url: 'https://github.com/user/repo/pull/456'
          }
        }
      end

      it 'extracts status from event field' do
        post "/webhooks/cursor/#{task.id}", params: payload, as: :json
        
        expect(task.reload.status).to eq('pr_open')
      end

      it 'extracts PR URL from data structure' do
        post "/webhooks/cursor/#{task.id}", params: payload, as: :json
        
        expect(task.reload.pr_url).to eq('https://github.com/user/repo/pull/456')
      end
    end

    context 'case insensitivity' do
      it 'handles lowercase status' do
        post "/webhooks/cursor/#{task.id}", params: { status: 'finished', pr_url: 'https://github.com/user/repo/pull/789' }, as: :json
        
        expect(task.reload.status).to eq('pr_open')
      end

      it 'handles mixed case status' do
        post "/webhooks/cursor/#{task.id}", params: { status: 'Finished', pr_url: 'https://github.com/user/repo/pull/789' }, as: :json
        
        expect(task.reload.status).to eq('pr_open')
      end
    end

    context 'when an exception occurs' do
      before do
        allow(Task).to receive(:find_by).and_raise(StandardError, 'Database error')
      end

      it 'returns 500 error' do
        post "/webhooks/cursor/#{task.id}", params: { status: 'FINISHED' }, as: :json
        
        expect(response).to have_http_status(:internal_server_error)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Internal server error')
      end
    end
  end
end
